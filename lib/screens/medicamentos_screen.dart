import 'package:flutter/material.dart';
import '../models/medicamento.dart';
import '../widgets/medicamento_card.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import 'cadastro_medicamento_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MedicamentosScreen extends StatefulWidget {
  const MedicamentosScreen({super.key});

  @override
  _MedicamentosScreenState createState() => _MedicamentosScreenState();
}

class _MedicamentosScreenState extends State<MedicamentosScreen> {
  final List<Medicamento> medicamentos = [];
  static const int LIMITE_MEDICAMENTOS = 4;

  final MqttService _mqttService = MqttService();
  final NotificationService _notificationService = NotificationService();

  bool _mqttConnected = false;
  String _statusConnection = 'Desconectado';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Inicializa serviços de notificação e MQTT
  Future<void> _initializeServices() async {
    // Inicializa notificações
    await _notificationService.initialize();
    await _notificationService.requestPermissions();

    // Carrega medicamentos
    await _loadMedicamentos();

    // Conecta ao MQTT
    await _connectMqtt();
  }

  Future<void> _loadMedicamentos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicamentosJson = prefs.getStringList('medicamentos') ?? [];

      setState(() {
        medicamentos.clear();
        for (String jsonString in medicamentosJson) {
          final Map<String, dynamic> data = json.decode(jsonString);
          medicamentos.add(Medicamento(
            titulo: data['titulo'],
            dose: data['dose'],
            horario: data['horario'],
            validade: data['validade'],
            cor: Color(data['cor']),
          ));
        }
      });

      // Reagenda notificações para todos os medicamentos carregados
      await _reagendarTodasNotificacoes();

      print('💾 ${medicamentos.length} medicamentos carregados');
    } catch (e) {
      print('❌ Erro ao carregar medicamentos: $e');
    }
  }

  Future<void> _saveMedicamentos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicamentosJson = medicamentos
          .map((med) => json.encode({
                'titulo': med.titulo,
                'dose': med.dose,
                'horario': med.horario,
                'validade': med.validade,
                'cor': med.cor.value,
              }))
          .toList();

      await prefs.setStringList('medicamentos', medicamentosJson);

      // Envia JSON completo para o ESP32
      if (_mqttConnected) {
        await _mqttService.enviarMedicamentos(medicamentos);
      }

      print('💾 Medicamentos salvos com sucesso');
    } catch (e) {
      print('❌ Erro ao salvar medicamentos: $e');
    }
  }

  /// Reagenda todas as notificações (usado após exclusão)
  Future<void> _reagendarTodasNotificacoes() async {
    print('🔄 Reagendando todas as notificações...');
    for (int i = 0; i < medicamentos.length; i++) {
      await _notificationService.agendarNotificacoes(medicamentos[i], i);
    }
    print('✅ Notificações reagendadas!');
  }

  Future<void> _connectMqtt() async {
    setState(() {
      _statusConnection = 'Conectando...';
    });

    // IMPORTANTE: Substitua pelo IP do seu broker MQTT
    final connected = await _mqttService.connect(
      broker: '192.168.1.100', // ← COLOQUE O IP DO SEU BROKER AQUI
      port: 1883,
    );

    setState(() {
      _mqttConnected = connected;
      _statusConnection = connected ? 'Conectado' : 'Erro de conexão';
    });

    if (connected && medicamentos.isNotEmpty) {
      // Envia todos os medicamentos em um único JSON
      await _mqttService.enviarMedicamentos(medicamentos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header com status MQTT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5282),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Medicamentos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _mqttConnected ? Icons.wifi : Icons.wifi_off,
                        color: _mqttConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ESP32: $_statusConnection',
                        style: TextStyle(
                          color: _mqttConnected
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                          fontSize: 14,
                        ),
                      ),
                      if (!_mqttConnected) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _connectMqtt,
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Botão de teste de notificação
                  GestureDetector(
                    onTap: _testarNotificacao,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notification_add,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Testar Notificação',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lista de medicamentos OU mensagem quando vazia
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: medicamentos.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: medicamentos.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () async {
                              await _navegarParaEdicao(index);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MedicamentoCard(
                                medicamento: medicamentos[index],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: medicamentos.length >= LIMITE_MEDICAMENTOS
          ? null
          : FloatingActionButton(
              onPressed: _navegarParaCadastro,
              backgroundColor: const Color(0xFF4A90E2),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum medicamento cadastrado',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no botão + para adicionar seu primeiro medicamento',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _navegarParaCadastro() async {
    if (medicamentos.length >= LIMITE_MEDICAMENTOS) {
      _mostrarAlertaLimite();
      return;
    }

    final novoMed = await Navigator.push<Medicamento>(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroMedicamentoScreen(
          corPredefinida: obterCorPorPosicao(medicamentos.length),
        ),
      ),
    );

    if (novoMed != null) {
      setState(() {
        medicamentos.add(novoMed);
      });

      await _saveMedicamentos();

      // Agenda notificações para o novo medicamento
      final indice = medicamentos.length - 1;
      await _notificationService.agendarNotificacoes(novoMed, indice);

      // Envia medicamento para ESP32
      if (_mqttConnected) {
        await _mqttService.enviarMedicamento(novoMed);
        _mostrarSnackBar(
          'Medicamento adicionado e enviado ao ESP32! ✅',
          Colors.green,
        );
      } else {
        _mostrarSnackBar(
          'Medicamento adicionado! (Offline - conecte ao ESP32)',
          Colors.orange,
        );
      }
    }
  }

  Future<void> _navegarParaEdicao(int index) async {
    final resultado = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroMedicamentoScreen(
          medicamentoParaEditar: medicamentos[index],
          indiceEdicao: index,
          corPredefinida: medicamentos[index].cor,
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        if (resultado == 'excluir') {
          // Cancela notificações do medicamento
          _notificationService.cancelarNotificacoesMedicamento(index);

          // Notifica ESP32 sobre exclusão
          if (_mqttConnected) {
            _mqttService.excluirMedicamento(index);
          }

          medicamentos.removeAt(index);
          _mostrarSnackBar('Medicamento removido! ✅', Colors.orange);
        } else if (resultado is Medicamento) {
          medicamentos[index] = resultado;

          // Reagenda notificações do medicamento atualizado
          _notificationService.agendarNotificacoes(resultado, index);

          // Atualiza no ESP32
          if (_mqttConnected) {
            _mqttService.enviarMedicamento(resultado);
          }

          _mostrarSnackBar('Medicamento atualizado! ✅', Colors.blue);
        }
      });

      await _saveMedicamentos();

      // Reagenda TODAS as notificações após qualquer mudança
      // (necessário porque os índices podem ter mudado após exclusão)
      await _reagendarTodasNotificacoes();
    }
  }

  /// Testa notificação imediata
  Future<void> _testarNotificacao() async {
    await _notificationService.testarNotificacaoImediata(
      'Teste de Notificação 💊',
      'Se você está vendo isso, as notificações estão funcionando!',
    );
    _mostrarSnackBar('Notificação de teste enviada! ✅', Colors.blue);
  }

  void _mostrarAlertaLimite() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limite atingido'),
          content: Text(
            'Você já cadastrou o máximo de $LIMITE_MEDICAMENTOS medicamentos.\n'
            'Este é o limite suportado pelo Dispositivo.',
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }
}
