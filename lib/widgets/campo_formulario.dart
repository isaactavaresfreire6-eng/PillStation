import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CampoFormulario extends StatelessWidget {
  final Widget? iconeWidget;
  final String titulo;
  final String placeholder;
  final TextEditingController controller;
  final IconData iconeFallback;
  final TextInputType? keyboardType;
  final String? tipoValidacao; // 'numero', 'data', 'hora'

  const CampoFormulario({
    Key? key,
    this.iconeWidget,
    required this.titulo,
    required this.placeholder,
    required this.controller,
    required this.iconeFallback,
    this.keyboardType,
    this.tipoValidacao,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 45,
              height: 45,
              child: iconeWidget ??
                  Icon(iconeFallback, size: 32, color: const Color(0xFF2C5282)),
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C5282),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: _getInputFormatters(),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<TextInputFormatter> _getInputFormatters() {
    List<TextInputFormatter> formatters = [];

    switch (tipoValidacao) {
      case 'numero':
        // Permite apenas números
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        break;

      case 'data':
        // Permite apenas números e formata como dd/mm/aaaa
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        formatters.add(DataInputFormatter());
        formatters.add(LengthLimitingTextInputFormatter(10)); // dd/mm/aaaa
        break;

      case 'hora':
        // Permite apenas números e formata como hh:mm com validação até 23:59
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        formatters.add(HoraInputFormatter());
        formatters.add(LengthLimitingTextInputFormatter(5)); // hh:mm
        break;

      default:
        // Sem formatação especial
        break;
    }

    return formatters;
  }
}

// Formatador para data (dd/mm/aaaa)
class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // Remove todos os caracteres não numéricos
    text = text.replaceAll(RegExp(r'[^0-9]'), '');

    // Aplica a formatação
    if (text.length >= 2) {
      text = text.substring(0, 2) + '/' + text.substring(2);
    }
    if (text.length >= 5) {
      text = text.substring(0, 5) + '/' + text.substring(5);
    }

    // Limita a 10 caracteres (dd/mm/aaaa)
    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// Formatador para hora (hh:mm) com validação até 23:59
class HoraInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // Remove todos os caracteres não numéricos
    text = text.replaceAll(RegExp(r'[^0-9]'), '');

    // Se está digitando e o primeiro dígito da hora é maior que 2, limita
    if (text.length >= 1) {
      int primeiroDigito = int.parse(text[0]);
      if (primeiroDigito > 2) {
        // Não permite horas que começam com 3, 4, 5, etc.
        return oldValue;
      }
    }

    // Se está digitando o segundo dígito da hora
    if (text.length >= 2) {
      int horas = int.parse(text.substring(0, 2));
      if (horas > 23) {
        // Se as horas passaram de 23, volta para o valor anterior
        return oldValue;
      }
      text = text.substring(0, 2) + ':' + text.substring(2);
    }

    // Se está digitando os minutos
    if (text.length >= 4) {
      String minutosStr = text.substring(3);
      if (minutosStr.length >= 1) {
        int primeiroDigitoMinuto = int.parse(minutosStr[0]);
        if (primeiroDigitoMinuto > 5) {
          // Não permite minutos que começam com 6, 7, 8, 9
          return oldValue;
        }
      }
      if (minutosStr.length >= 2) {
        int minutos = int.parse(minutosStr.substring(0, 2));
        if (minutos > 59) {
          // Se os minutos passaram de 59, volta para o valor anterior
          return oldValue;
        }
      }
    }

    // Limita a 5 caracteres (hh:mm)
    if (text.length > 5) {
      text = text.substring(0, 5);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
