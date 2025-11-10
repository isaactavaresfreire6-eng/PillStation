import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/medicamento.dart';

/// Serviço MQTT para comunicação com ESP32
class MqttService {
  // Configurações do broker
  static const String _broker = 'broker.hivemq.com';
  static const int _port = 1883;
  static const String _clientId = 'pillstation-app-flutter';

  // Tópicos MQTT
  static const String _topicStatus = 'pillstation/status';
  static const String _topicMedicamentos = 'pillstation/medicamentos';
  static const String _topicConfirmacao = 'pillstation/confirmacao';

  // Cliente MQTT
  MqttServerClient? _client;
  bool _connected = false;

  // StreamController para status de conexão
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // StreamController para mensagens recebidas
  final _mensagensController = StreamController<String>.broadcast();
  Stream<String> get mensagensStream => _mensagensController.stream;

  /// Conecta ao broker MQTT
  Future<bool> connect({
    required String broker,
    required int port,
  }) async {
    print('📡 MQTT: Tentando conectar ao broker $broker:$port');
    _statusController.add('Conectando...');

    try {
      // Cria cliente MQTT
      _client = MqttServerClient.withPort(_broker, _clientId, _port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;

      // Configura mensagem de última vontade (caso o app caia)
      final connMess = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .withWillTopic('pillstation/app/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMess;

      // Tenta conectar
      print('🔄 Conectando ao broker...');
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ Conectado ao broker MQTT!');
        _connected = true;
        _statusController.add('Conectado');

        // Inscreve nos tópicos
        _inscreveTopicos();

        // Publica status do app
        _publicaMensagem('pillstation/app/status', 'online');

        return true;
      } else {
        print('❌ Falha na conexão: ${_client!.connectionStatus}');
        _statusController.add('Erro: ${_client!.connectionStatus}');
        _client!.disconnect();
        _connected = false;
        return false;
      }
    } catch (e) {
      print('❌ Erro ao conectar: $e');
      _statusController.add('Erro: $e');
      _connected = false;
      return false;
    }
  }

  /// Inscreve nos tópicos MQTT
  void _inscreveTopicos() {
    print('📥 Inscrevendo nos tópicos...');

    // Inscreve no tópico de status do ESP32
    _client!.subscribe(_topicStatus, MqttQos.atLeastOnce);

    // Inscreve no tópico de confirmações do ESP32
    _client!.subscribe(_topicConfirmacao, MqttQos.atLeastOnce);

    // Listener para mensagens recebidas
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String mensagem =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('📩 Mensagem recebida: ${c[0].topic} -> $mensagem');
      _mensagensController.add('${c[0].topic}|$mensagem');

      // Se recebeu status "online", significa que ESP32 conectou
      if (c[0].topic == _topicStatus && mensagem == 'online') {
        _statusController.add('ESP32 Online');
      }
    });
  }

  /// Publica uma mensagem em um tópico
  void _publicaMensagem(String topico, String mensagem) {
    if (!_connected || _client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(mensagem);
    _client!.publishMessage(topico, MqttQos.atLeastOnce, builder.payload!);
    print('📤 Publicado em $topico: $mensagem');
  }

  /// Envia medicamento individual para o ESP32
  Future<void> enviarMedicamento(Medicamento medicamento) async {
    if (!_connected) {
      print('📤 MQTT: Não conectado, não é possível enviar');
      return;
    }

    final json = jsonEncode({
      'titulo': medicamento.titulo,
      'dose': medicamento.dose,
      'horario': medicamento.horario,
      'validade': medicamento.validade,
      'cor': medicamento.cor.value,
    });

    _publicaMensagem(_topicMedicamentos, json);
    print('📤 Medicamento enviado: ${medicamento.titulo}');
  }

  /// Envia lista completa de medicamentos para o ESP32
  Future<void> enviarMedicamentos(List<Medicamento> medicamentos) async {
    if (!_connected) {
      print('📤 MQTT: Não conectado, não é possível enviar');
      return;
    }

    final listaJson = medicamentos
        .map((med) => {
              'titulo': med.titulo,
              'dose': med.dose,
              'horario': med.horario,
              'validade': med.validade,
              'cor': med.cor.value,
            })
        .toList();

    final json = jsonEncode({'medicamentos': listaJson});
    _publicaMensagem(_topicMedicamentos, json);
    print('📤 ${medicamentos.length} medicamentos enviados');
  }

  /// Exclui medicamento (envia índice para ESP32)
  Future<void> excluirMedicamento(int indice) async {
    if (!_connected) {
      print('🗑️ MQTT: Não conectado');
      return;
    }

    final json = jsonEncode({'acao': 'excluir', 'indice': indice});
    _publicaMensagem(_topicMedicamentos, json);
    print('🗑️ Exclusão enviada: índice $indice');
  }

  /// Callbacks de conexão
  void _onConnected() {
    print('🟢 Callback: Conectado ao broker');
    _statusController.add('Conectado');
  }

  void _onDisconnected() {
    print('🔴 Callback: Desconectado do broker');
    _connected = false;
    _statusController.add('Desconectado');
  }

  void _onAutoReconnect() {
    print('🔄 Tentando reconectar automaticamente...');
    _statusController.add('Reconectando...');
  }

  void _onAutoReconnected() {
    print('✅ Reconectado automaticamente!');
    _connected = true;
    _statusController.add('Reconectado');
  }

  /// Desconecta do broker
  void disconnect() {
    print('🔌 Desconectando do MQTT...');
    _publicaMensagem('pillstation/app/status', 'offline');
    _client?.disconnect();
    _connected = false;
    _statusController.add('Desconectado');
  }

  /// Verifica se está conectado
  bool get isConnected => _connected;

  /// Limpa recursos ao destruir o serviço
  void dispose() {
    _statusController.close();
    _mensagensController.close();
    disconnect();
  }
}
