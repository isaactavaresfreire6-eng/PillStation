// services/mqtt_service.dart
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart'; // Para Web
import '../models/medicamento.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttClient? _client;
  bool _isConnected = false;

  // Topics MQTT
  static const String topicMedicamentos = 'pillstation/medicamentos';
  static const String topicStatus = 'pillstation/status';
  static const String topicComando = 'pillstation/comando';

  bool get isConnected => _isConnected;

  Future<bool> connect({
    String broker = 'broker.hivemq.com',
    int port = 8000, // ✅ HiveMQ WebSocket com CORS liberado
    String clientId = 'flutter_pillstation',
  }) async {
    try {
      // Cria cliente MQTT para navegador (WebSocket)
      _client = MqttBrowserClient('ws://$broker', clientId);
      _client!.port = port;
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;

      _client!.logging(on: true);

      print('🔄 Conectando ao broker MQTT (WebSocket): ws://$broker:$port');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(
              clientId + '_' + DateTime.now().millisecondsSinceEpoch.toString())
          .withWillTopic('pillstation/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ Conectado ao broker MQTT!');
        _isConnected = true;

        // Publica status online
        _publishStatus('online');

        // Inscreve nos tópicos de resposta do ESP32
        _client!.subscribe('$topicStatus/esp32', MqttQos.atMostOnce);

        return true;
      }
    } catch (e) {
      print('❌ Erro ao conectar MQTT: $e');
    }

    _isConnected = false;
    return false;
  }

  void _onConnected() {
    print('✅ Cliente MQTT conectado');
    _isConnected = true;
  }

  void _onDisconnected() {
    print('❌ Cliente MQTT desconectado');
    _isConnected = false;
  }

  void _onAutoReconnect() {
    print('🔄 Reconectando automaticamente...');
  }

  Future<void> enviarMedicamentos(List<Medicamento> medicamentos) async {
    if (!_isConnected || _client == null) {
      print('❌ MQTT não conectado');
      return;
    }

    try {
      // Envia cada medicamento individualmente
      for (int i = 0; i < medicamentos.length; i++) {
        await enviarMedicamento(medicamentos[i]);
        // Pequeno delay para evitar spam de mensagens
        await Future.delayed(Duration(milliseconds: 300));
      }
      print('✅ Todos os medicamentos enviados com sucesso!');
    } catch (e) {
      print('❌ Erro ao enviar medicamentos: $e');
    }
  }

  Future<void> enviarMedicamento(Medicamento medicamento) async {
    if (!_isConnected || _client == null) {
      print('❌ MQTT não conectado');
      return;
    }

    try {
      // CORREÇÃO: Converte o intervalo (HH:MM) para milissegundos
      final intervaloDoses = _converterHorarioParaMs(medicamento.horario);

      final payload = json.encode({
        'nome': medicamento.titulo,
        'intervalo': intervaloDoses, // ✅ ENVIA EM MILISSEGUNDOS
        'dose': medicamento.dose, // Primeira dose (HH:MM)
        'validade': medicamento.validade,
        'ativo': !medicamento.estaVencido,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('📤 Enviando medicamento via MQTT:');
      print(payload);

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        topicMedicamentos,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('✅ Medicamento enviado com sucesso!');
      print('   Nome: ${medicamento.titulo}');
      print(
          '   Intervalo: $intervaloDoses ms (${intervaloDoses / 3600000} horas)');
    } catch (e) {
      print('❌ Erro ao enviar medicamento: $e');
    }
  }

  Future<void> excluirMedicamento(int posicao) async {
    if (!_isConnected || _client == null) {
      print('❌ MQTT não conectado');
      return;
    }

    try {
      final payload = json.encode({
        'acao': 'excluir',
        'posicao': posicao,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('📤 Excluindo medicamento posição $posicao via MQTT');

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        topicMedicamentos,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('✅ Comando de exclusão enviado!');
    } catch (e) {
      print('❌ Erro ao excluir medicamento: $e');
    }
  }

  // Converte horário HH:MM para milissegundos
  int _converterHorarioParaMs(String horario) {
    try {
      final partes = horario.split(':');
      if (partes.length == 2) {
        final horas = int.parse(partes[0]);
        final minutos = int.parse(partes[1]);
        return (horas * 60 + minutos) * 60 * 1000; // converte para ms
      }
    } catch (e) {
      print('Erro ao converter horário: $e');
    }
    return 8 * 60 * 60 * 1000; // padrão 8 horas em ms
  }

  Future<void> enviarComando(String comando,
      {Map<String, dynamic>? dados}) async {
    if (!_isConnected || _client == null) return;

    try {
      final payload = json.encode({
        'comando': comando,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'dados': dados ?? {},
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        topicComando,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('📤 Comando enviado: $comando');
    } catch (e) {
      print('❌ Erro ao enviar comando: $e');
    }
  }

  void _publishStatus(String status) {
    if (_client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(json.encode({
      'status': status,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));

    _client!.publishMessage(
      topicStatus,
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    if (_client != null) {
      _publishStatus('offline');
      _client!.disconnect();
      _isConnected = false;
    }
  }

  // Escuta mensagens do ESP32
  Stream<String> get messagesStream {
    if (_client == null) return Stream.empty();

    return _client!.updates!.map((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);
      return payload;
    });
  }
}
