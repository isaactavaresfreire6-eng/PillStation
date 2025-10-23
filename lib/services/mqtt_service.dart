// services/mqtt_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/medicamento.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  StreamController<String>? _messageController;

  // Topics MQTT
  static const String topicMedicamentos = 'pillstation/medicamentos';
  static const String topicStatusESP = 'pillstation/status/esp32';
  static const String topicStatusApp = 'pillstation/status/app';

  bool get isConnected => _isConnected;

  /// Conecta ao broker MQTT público
  Future<bool> connect({
    String broker = 'broker.hivemq.com',
    int port = 1883,
    String clientId = 'flutter_pillstation',
  }) async {
    if (_isConnected && _client != null) {
      print('✅ Já conectado ao broker MQTT');
      return true;
    }

    try {
      print('\n========================================');
      print('INICIANDO CONEXÃO MQTT');
      print('========================================');
      print('Broker: $broker:$port');
      print('Cliente: $clientId');

      await _cleanupConnection();

      final uniqueClientId =
          '${clientId}_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient(broker, uniqueClientId);
      _client!.port = port;
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;

      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;

      _client!.logging(on: false);
      _client!.setProtocolV311();

      print('🔄 Conectando ao broker MQTT...');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(uniqueClientId)
          .withWillTopic(topicStatusApp)
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        print('✅ CONECTADO AO BROKER MQTT!');
        _isConnected = true;

        _publishStatus('online');
        _subscribeToTopics();
        _setupMessageStream();

        print('========================================\n');
        return true;
      } else {
        print(
            '❌ Falha na conexão. Estado: ${_client?.connectionStatus?.state}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      print('❌ Erro ao conectar MQTT: $e');
      print('Verifique se:');
      print('  1. O ESP32 está ligado e conectado à rede Isaac');
      print('  2. O ESP32 consegue acessar a internet');
      print('  3. Ambos estão usando o broker: $broker');
      print('========================================\n');
      _isConnected = false;
      return false;
    }
  }

  void _onConnected() {
    print('✅ Cliente MQTT conectado');
    _isConnected = true;
    _publishStatus('online');
  }

  void _onDisconnected() {
    print('❌ Cliente MQTT desconectado');
    _isConnected = false;
  }

  void _onAutoReconnect() {
    print('🔄 Reconectando automaticamente ao broker...');
  }

  void _subscribeToTopics() {
    if (_client == null) return;

    try {
      _client!.subscribe(topicStatusESP, MqttQos.atLeastOnce);
      _client!.subscribe('$topicMedicamentos/resposta', MqttQos.atLeastOnce);
      print('📥 Inscrito nos tópicos de resposta');
    } catch (e) {
      print('❌ Erro ao inscrever em tópicos: $e');
    }
  }

  void _setupMessageStream() {
    _messageController?.close();
    _messageController = StreamController<String>.broadcast();

    _client?.updates?.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final mqttMessage = message.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(
            mqttMessage.payload.message,
          );

          print('\n📨 Mensagem recebida:');
          print('Tópico: ${message.topic}');
          print('Payload: $payload');

          _messageController?.add(payload);
        }
      },
      onError: (error) {
        print('❌ Erro no stream de mensagens: $error');
      },
    );
  }

  /// Envia vários medicamentos com suas posições
  Future<void> enviarMedicamentos(List<Medicamento> medicamentos) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT não conectado! Conecte primeiro ao broker.');
    }

    try {
      print('\n========================================');
      print('📤 ENVIANDO ${medicamentos.length} MEDICAMENTOS');
      print('========================================');

      for (int i = 0; i < medicamentos.length; i++) {
        print('\n📦 Medicamento ${i + 1}/${medicamentos.length} (Posição $i):');
        await enviarMedicamento(medicamentos[i], posicao: i);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('\n✅ Todos os medicamentos enviados!');
      print('========================================\n');
    } catch (e) {
      print('❌ Erro ao enviar medicamentos: $e');
      rethrow;
    }
  }

  /// Envia um medicamento individual
  Future<void> enviarMedicamento(Medicamento medicamento,
      {int? posicao}) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT não conectado! Conecte primeiro ao broker.');
    }

    try {
      final intervaloMs = _converterHorarioParaMs(medicamento.horario);

      final payload = json.encode({
        'nome': medicamento.titulo,
        'intervalo': intervaloMs,
        'dose': medicamento.dose,
        'validade': medicamento.validade,
        'ativo': !medicamento.estaVencido,
        'posicao': posicao, // Adiciona posição do medicamento
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('📋 Dados:');
      if (posicao != null) print('   Posição: $posicao');
      print('   Nome: ${medicamento.titulo}');
      print('   Horário: ${medicamento.horario}');
      print(
          '   Intervalo: ${intervaloMs}ms (${(intervaloMs / 3600000).toStringAsFixed(1)}h)');
      print('   Ativo: ${!medicamento.estaVencido}');

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        topicMedicamentos,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('✅ Mensagem publicada em: $topicMedicamentos');
    } catch (e) {
      print('❌ Erro ao enviar medicamento: $e');
      rethrow;
    }
  }

  /// Exclui medicamento do ESP32
  Future<void> excluirMedicamento(int posicao) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT não conectado!');
    }

    try {
      print('\n========================================');
      print('🗑️ EXCLUINDO MEDICAMENTO NA POSIÇÃO $posicao');
      print('========================================');

      final payload = json.encode({
        'acao': 'excluir',
        'posicao': posicao,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        topicMedicamentos,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('✅ Comando de exclusão enviado!');
      print('========================================\n');
    } catch (e) {
      print('❌ Erro ao excluir medicamento: $e');
      rethrow;
    }
  }

  /// Converte horário HH:MM para milissegundos
  /// Exemplo: "08:00" = 8 horas = 28.800.000 ms
  int _converterHorarioParaMs(String horario) {
    try {
      final partes = horario.split(':');
      if (partes.length != 2) {
        throw FormatException('Formato de horário inválido: $horario');
      }

      final horas = int.parse(partes[0]);
      final minutos = int.parse(partes[1]);

      if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59) {
        throw RangeError('Horário fora do intervalo válido: $horario');
      }

      final totalMinutos = (horas * 60) + minutos;
      final milissegundos = totalMinutos * 60 * 1000;

      print('🔄 Conversão: $horario → ${milissegundos}ms');

      return milissegundos;
    } catch (e) {
      print('❌ Erro ao converter horário "$horario": $e');
      print('⚠️ Usando intervalo padrão de 8 horas');
      return 8 * 60 * 60 * 1000; // 28800000 ms
    }
  }

  /// Envia comando genérico para o ESP32
  Future<void> enviarComando(
    String comando, {
    Map<String, dynamic>? dados,
  }) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT não conectado!');
    }

    try {
      print('\n📤 Enviando comando: $comando');

      final payload = json.encode({
        'comando': comando,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'dados': dados ?? {},
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        '$topicMedicamentos/comando',
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('✅ Comando enviado!');
    } catch (e) {
      print('❌ Erro ao enviar comando: $e');
      rethrow;
    }
  }

  /// Publica status do app
  void _publishStatus(String status) {
    if (_client == null || !_isConnected) return;

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode({
        'status': status,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'device': 'flutter_app',
      }));

      _client!.publishMessage(
        topicStatusApp,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('📡 Status publicado: $status');
    } catch (e) {
      print('❌ Erro ao publicar status: $e');
    }
  }

  /// Limpa conexão anterior
  Future<void> _cleanupConnection() async {
    if (_client != null) {
      try {
        _client!.disconnect();
      } catch (e) {
        print('⚠️ Erro ao limpar conexão anterior: $e');
      }
      _client = null;
    }
    _isConnected = false;
  }

  /// Desconecta do broker
  Future<void> disconnect() async {
    if (_client != null) {
      print('\n🔌 Desconectando do broker MQTT...');
      _publishStatus('offline');

      await Future.delayed(const Duration(milliseconds: 100));

      _client!.disconnect();
      _isConnected = false;

      await _messageController?.close();
      _messageController = null;

      print('✅ Desconectado com sucesso!\n');
    }
  }

  /// Stream de mensagens do ESP32
  Stream<String> get messagesStream {
    return _messageController?.stream ?? Stream.empty();
  }

  /// Testa a conexão MQTT
  Future<bool> testarConexao() async {
    if (!_isConnected || _client == null) {
      print('❌ MQTT não está conectado');
      return false;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode({
        'teste': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      _client!.publishMessage(
        '$topicStatusApp/ping',
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('✅ Conexão MQTT ativa');
      return true;
    } catch (e) {
      print('❌ Erro ao testar conexão: $e');
      return false;
    }
  }

  /// Libera recursos quando não mais necessário
  void dispose() {
    disconnect();
  }
}
