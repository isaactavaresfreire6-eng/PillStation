import '../models/medicamento.dart';

/// Serviço MQTT simplificado - apenas estrutura básica
/// Remove funcionalidades web para evitar problemas no mobile
class MqttService {
  bool _connected = false;

  /// Simula conexão MQTT (desabilitado para testes mobile)
  Future<bool> connect({
    required String broker,
    required int port,
  }) async {
    print('📡 MQTT: Modo simulado - conexão desabilitada para testes');
    _connected = false;
    return false; // Retorna false para não tentar enviar dados
  }

  /// Simula envio de medicamento
  Future<void> enviarMedicamento(Medicamento medicamento) async {
    if (!_connected) {
      print('📤 MQTT: Modo simulado - envio desabilitado');
      return;
    }
    print('📤 Enviando: ${medicamento.titulo}');
  }

  /// Simula envio de lista de medicamentos
  Future<void> enviarMedicamentos(List<Medicamento> medicamentos) async {
    if (!_connected) {
      print('📤 MQTT: Modo simulado - envio desabilitado');
      return;
    }
    print('📤 Enviando ${medicamentos.length} medicamentos');
  }

  /// Simula exclusão de medicamento
  Future<void> excluirMedicamento(int indice) async {
    if (!_connected) {
      print('🗑️ MQTT: Modo simulado - exclusão desabilitada');
      return;
    }
    print('🗑️ Excluindo medicamento índice: $indice');
  }

  /// Desconecta (não faz nada no modo simulado)
  void disconnect() {
    print('🔌 MQTT: Desconectado (modo simulado)');
    _connected = false;
  }

  /// Verifica se está conectado
  bool get isConnected => _connected;
}
