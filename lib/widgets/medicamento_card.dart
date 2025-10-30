import 'package:flutter/material.dart';
import '../models/medicamento.dart';

class MedicamentoCard extends StatefulWidget {
  final Medicamento medicamento;

  const MedicamentoCard({Key? key, required this.medicamento})
      : super(key: key);

  @override
  State<MedicamentoCard> createState() => _MedicamentoCardState();
}

class _MedicamentoCardState extends State<MedicamentoCard> {
  static const int LIMITE_DOSES = 6;

  @override
  void initState() {
    super.initState();
    // Atualiza o card a cada minuto
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {});
        initState(); // Reagenda o próximo update
      }
    });
  }

  /// Calcula a próxima dose e quantas doses já foram tomadas
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

      // Se a primeira dose ainda não chegou hoje
      if (primeiraDose.isAfter(agora)) {
        return {'proximaDose': widget.medicamento.dose, 'dosesTomadas': 0};
      }

      // Calcula quantas doses já passaram desde a primeira dose
      final diferencaMinutos = agora.difference(primeiraDose).inMinutes;
      final intervaloEmMinutos = (horasIntervalo * 60) + minutosIntervalo;

      if (intervaloEmMinutos == 0) {
        return {'proximaDose': widget.medicamento.dose, 'dosesTomadas': 0};
      }

      // Calcula número de doses já tomadas
      final dosesTomadas = (diferencaMinutos / intervaloEmMinutos).floor() + 1;

      // Se já passou do limite, retorna info de reposição
      if (dosesTomadas >= LIMITE_DOSES) {
        return {
          'proximaDose': '--:--',
          'dosesTomadas': dosesTomadas,
          'precisaRepor': true
        };
      }

      // Calcula a próxima dose
      final proximaDose = primeiraDose.add(
        Duration(minutes: dosesTomadas * intervaloEmMinutos),
      );

      // Formata para HH:MM
      final hora = proximaDose.hour.toString().padLeft(2, '0');
      final minuto = proximaDose.minute.toString().padLeft(2, '0');

      return {
        'proximaDose': '$hora:$minuto',
        'dosesTomadas': dosesTomadas,
        'precisaRepor': false
      };
    } catch (e) {
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
