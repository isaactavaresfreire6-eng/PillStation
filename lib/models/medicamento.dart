import 'package:flutter/material.dart';

class Medicamento {
  final String titulo;
  final String dose; // Horário da primeira dose (ex: "08:00")
  final String horario; // Intervalo entre doses (ex: "08:00")
  final String validade;
  final Color cor;

  Medicamento({
    required this.titulo,
    required this.dose,
    required this.horario,
    required this.validade,
    required this.cor,
  });

  // Verifica se o medicamento está vencido
  bool get estaVencido {
    if (validade.isEmpty) return false;
    try {
      final partesData = validade.split('/');
      if (partesData.length != 3) return false;

      final dia = int.parse(partesData[0]);
      final mes = int.parse(partesData[1]);
      final ano = int.parse(partesData[2]);

      final dataValidade = DateTime(ano, mes, dia);
      final hoje = DateTime.now();
      return dataValidade.isBefore(hoje);
    } catch (_) {
      return false;
    }
  }

  // Converte horário "HH:mm" para minutos
  int _horarioParaMinutos(String horario) {
    try {
      final partes = horario.split(':');
      if (partes.length == 2) {
        final horas = int.parse(partes[0]);
        final minutos = int.parse(partes[1]);
        return horas * 60 + minutos;
      }
    } catch (_) {}
    return 0;
  }

  // Converte minutos para horário "HH:mm"
  String _minutosParaHorario(int minutos) {
    final horas = (minutos ~/ 60) % 24; // Garante que não passe de 24h
    final mins = minutos % 60;
    return '${horas.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // Calcula o horário da próxima dose (baseado em 6 doses por dia)
  String? get proximaDose {
    try {
      final agora = DateTime.now();
      final minutosPrimeiraDose = _horarioParaMinutos(dose);
      final minutosIntervalo = _horarioParaMinutos(horario);

      // Calcula os horários das 6 doses
      for (int i = 0; i < 6; i++) {
        final minutosDose = minutosPrimeiraDose + (minutosIntervalo * i);
        final horarioDose = _minutosParaHorario(minutosDose);

        // Converte para DateTime de hoje
        final partesHorario = horarioDose.split(':');
        final horasDose = int.parse(partesHorario[0]);
        final minutosDoseAtual = int.parse(partesHorario[1]);

        final dataHoraDose = DateTime(
          agora.year,
          agora.month,
          agora.day,
          horasDose,
          minutosDoseAtual,
        );

        // Se o horário ainda não passou, retorna como próxima dose
        if (dataHoraDose.isAfter(agora)) {
          return horarioDose;
        }
      }

      // Se todas as 6 doses já passaram, retorna null
      return null;
    } catch (_) {
      return null;
    }
  }

  // Verifica se todas as 6 doses já foram administradas hoje
  bool get todasDosesCompletas {
    return proximaDose == null;
  }

  // Cor do card (cinza se completou 6 doses, vermelho se vencido, ou cor normal)
  Color get corAtual {
    if (estaVencido) {
      return Colors.red.shade300;
    }
    if (todasDosesCompletas) {
      return Colors.grey.shade400; // Card cinza após 6 doses
    }
    return cor;
  }

  // Retorna a lista de todos os 6 horários do dia
  List<String> get todosHorariosDoDia {
    try {
      final minutosPrimeiraDose = _horarioParaMinutos(dose);
      final minutosIntervalo = _horarioParaMinutos(horario);

      return List.generate(6, (i) {
        final minutosDose = minutosPrimeiraDose + (minutosIntervalo * i);
        return _minutosParaHorario(minutosDose);
      });
    } catch (_) {
      return [];
    }
  }
}

// Lista de cores pastel na ordem exata: 1º azul, 2º laranja, 3º rosa, 4º amarelo
final List<Color> coresDisponiveis = [
  Color(0xFFB3D9FF), // 1º medicamento - Azul pastel
  Color(0xFFFFD4B3), // 2º medicamento - Laranja pastel
  Color(0xFFFFB3D9), // 3º medicamento - Rosa pastel
  Color(0xFFFFFAB3), // 4º medicamento - Amarelo pastel
];

// Função para obter a cor baseada na posição do medicamento
Color obterCorPorPosicao(int posicao) {
  return coresDisponiveis[posicao % coresDisponiveis.length];
}
