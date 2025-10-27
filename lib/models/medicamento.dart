import 'package:flutter/material.dart';

class Medicamento {
  final String titulo;
  final String dose;
  final String horario;
  final String validade;
  final Color cor;

  Medicamento({
    required this.titulo,
    required this.dose,
    required this.horario,
    required this.validade,
    required this.cor,
  });

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

  Color get corAtual {
    if (estaVencido) {
      return Colors.red.shade300;
    }
    return cor;
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
