import 'package:flutter/material.dart';
import '../models/medicamento.dart';

class MedicamentoCard extends StatelessWidget {
  final Medicamento medicamento;

  const MedicamentoCard({Key? key, required this.medicamento})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final proximaDose = medicamento.proximaDose;
    final todasCompletas = medicamento.todasDosesCompletas;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: medicamento.corAtual,
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
          // Ícone do medicamento
          Container(
            width: 50,
            height: 50,
            child: Image.asset(
              'assets/Inicial.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.medication,
                  size: 40,
                  color: todasCompletas
                      ? Colors.grey.shade600
                      : Colors.blue.shade600,
                );
              },
            ),
          ),
          const SizedBox(width: 16),

          // Nome do medicamento
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicamento.titulo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: todasCompletas
                        ? Colors.grey.shade700
                        : const Color(0xFF2D3748),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),

                // Próxima dose ou mensagem de completo
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: todasCompletas
                          ? Colors.grey.shade600
                          : const Color(0xFF718096),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      todasCompletas
                          ? 'Doses completas hoje'
                          : 'Próxima dose: $proximaDose',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: todasCompletas
                            ? Colors.grey.shade600
                            : const Color(0xFF4A5568),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Indicador visual de status
          if (todasCompletas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
