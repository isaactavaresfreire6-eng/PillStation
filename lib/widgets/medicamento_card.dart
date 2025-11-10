import 'package:flutter/material.dart';
import '../models/medicamento.dart';
import '../services/notification_service.dart';
import 'dart:async';

class MedicamentoCard extends StatefulWidget {
  final Medicamento medicamento;
  final int indice;

  const MedicamentoCard({
    Key? key,
    required this.medicamento,
    required this.indice, required onDoseTomada,
  }) : super(key: key);

  @override
  State<MedicamentoCard> createState() => _MedicamentoCardState();
}

class _MedicamentoCardState extends State<MedicamentoCard> {
  static const int LIMITE_DOSES = 6;
  Timer? _timer;
  int _dosesTomadasAnterior = -1;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Verifica a cada 5 segundos se é hora de uma nova dose
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _verificarENotificarDose();
      }
    });
    // Verifica imediatamente ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarENotificarDose();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Verifica se é hora de incrementar a dose e ENVIA NOTIFICAÇÃO
  void _verificarENotificarDose() {
    final dados = _calcularDadosDose();
    final dosesTomadas = dados['dosesTomadas'] ?? 0;

    // Se mudou o número de doses, ENVIA NOTIFICAÇÃO
    if (_dosesTomadasAnterior != -1 &&
        dosesTomadas > _dosesTomadasAnterior &&
        dosesTomadas <= LIMITE_DOSES) {
      
      print('🔔 DOSE $dosesTomadas/$LIMITE_DOSES CAIU AGORA!');
      
      // Envia notificação instantânea
      _notificationService.enviarNotificacaoImediata(
        widget.medicamento.titulo,
        dosesTomadas,
        LIMITE_DOSES,
      );
    }

    _dosesTomadasAnterior = dosesTomadas;

    if (mounted) {
      setState(() {});
    }
  }

  /// Calcula a próxima dose e quantas doses JÁ FORAM TOMADAS
  /// LÓGICA: 0/6 = nenhuma caiu ainda, 1/6 = primeira já caiu, ..., 6/6 = todas caíram
  Map<String, dynamic> _calcularDadosDose() {
    try {
      // Parse da primeira dose (formato: HH:MM)
      final partesHorario = widget.medicamento.dose.split(':');
      if (partesHorario.length != 2) {
        return {'proximaDose': widget.medicamento.dose, 'dosesTomadas': 0};
      }

      final horaInicial = int.parse(partesHorario[0]);
      final minutoInicial = int.parse(partesHorario[1]);

      // Parse do intervalo (formato: HH:MM)
      final partesIntervalo = widget.medicamento.horario.split(':');
      if (partesIntervalo.length != 2) {
        return {'proximaDose': widget.medicamento.dose, 'dosesTomadas': 0};
      }

      final horasIntervalo = int.parse(partesIntervalo[0]);
      final minutosIntervalo = int.parse(partesIntervalo[1]);

      // Calcula o intervalo em minutos
      final intervaloEmMinutos = (horasIntervalo * 60) + minutosIntervalo;

      if (intervaloEmMinutos == 0) {
        return {'proximaDose': widget.medicamento.dose, 'dosesTomadas': 0};
      }

      // Obtém hora atual
      final agora = DateTime.now();

      // Cria DateTime para a primeira dose de hoje
      DateTime primeiraDose = DateTime(
        agora.year,
        agora.month,
        agora.day,
        horaInicial,
        minutoInicial,
      );

      // Se a primeira dose ainda não chegou hoje → 0/6
      if (primeiraDose.isAfter(agora)) {
        final hora = primeiraDose.hour.toString().padLeft(2, '0');
        final minuto = primeiraDose.minute.toString().padLeft(2, '0');
        return {
          'proximaDose': '$hora:$minuto',
          'dosesTomadas': 0,
        };
      }

      // Calcula quantos minutos se passaram desde a primeira dose
      final minutosPassados = agora.difference(primeiraDose).inMinutes;

      // Calcula quantas doses JÁ CAÍRAM (passaram do horário)
      // minutosPassados = 0 a 239 → 0 doses caíram (ainda estamos na janela da primeira)
      // minutosPassados = 240+ → 1 dose caiu
      final dosesTomadas = (minutosPassados / intervaloEmMinutos).floor();

      // Limita a 6 doses
      final dosesTomadasLimitado = dosesTomadas > LIMITE_DOSES ? LIMITE_DOSES : dosesTomadas;

      // Se já atingiu o limite de 6 doses → Precisa repor
      if (dosesTomadasLimitado >= LIMITE_DOSES) {
        return {
          'proximaDose': '--:--',
          'dosesTomadas': LIMITE_DOSES,
          'precisaRepor': true
        };
      }

      // Calcula o horário da PRÓXIMA dose (que ainda não caiu)
      final proximaDoseDateTime = primeiraDose.add(
        Duration(minutes: (dosesTomadasLimitado + 1) * intervaloEmMinutos),
      );

      // Formata para HH:MM
      final hora = proximaDoseDateTime.hour.toString().padLeft(2, '0');
      final minuto = proximaDoseDateTime.minute.toString().padLeft(2, '0');

      return {
        'proximaDose': '$hora:$minuto',
        'dosesTomadas': dosesTomadasLimitado,
        'precisaRepor': false,
      };
    } catch (e) {
      print('❌ Erro ao calcular dose: $e');
      return {'proximaDose': widget.medicamento.dose, 'dosesTomadas': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _calcularDadosDose();
    final precisaRepor = dados['precisaRepor'] ?? false;
    final dosesTomadas = dados['dosesTomadas'] ?? 0;
    final proximaDose = dados['proximaDose'] ?? '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            precisaRepor ? Colors.grey.shade300 : widget.medicamento.corAtual,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            child: precisaRepor
                ? Icon(
                    Icons.warning_amber_rounded,
                    size: 40,
                    color: Colors.orange.shade700,
                  )
                : Image.asset(
                    'assets/Inicial.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.medication,
                        size: 40,
                        color: Colors.blue.shade600,
                      );
                    },
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.medicamento.titulo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: precisaRepor
                        ? Colors.grey.shade700
                        : const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                if (precisaRepor)
                  Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Precisa repor no dispositivo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Color(0xFF718096),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Próxima dose: ',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF718096),
                            ),
                          ),
                          Text(
                            proximaDose,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.medication,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Doses: $dosesTomadas/$LIMITE_DOSES',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}