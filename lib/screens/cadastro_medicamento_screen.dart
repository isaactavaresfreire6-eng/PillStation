import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medicamento.dart';

class CadastroMedicamentoScreen extends StatefulWidget {
  final Medicamento? medicamentoParaEditar;
  final int? indiceEdicao;
  final Color? corPredefinida;

  const CadastroMedicamentoScreen({
    Key? key,
    this.medicamentoParaEditar,
    this.indiceEdicao,
    this.corPredefinida,
  }) : super(key: key);

  @override
  _CadastroMedicamentoScreenState createState() =>
      _CadastroMedicamentoScreenState();
}

class _CadastroMedicamentoScreenState extends State<CadastroMedicamentoScreen> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController validadeController = TextEditingController();
  final TextEditingController primeiraDoseController = TextEditingController();
  final TextEditingController intervaloController = TextEditingController();

  bool validadeVencida = false;
  String? mensagemErroValidade;

  int get anoAtual => DateTime.now().year;
  bool get isEdicao => widget.medicamentoParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (isEdicao) {
      final med = widget.medicamentoParaEditar!;
      nomeController.text = med.titulo;
      validadeController.text = med.validade;

      // Converte "HH:mm" para "Xh Ym" se necessário
      intervaloController.text = _converterParaIntervalo(med.horario);
      primeiraDoseController.text = med.dose;
    }

    validadeController.addListener(_validarValidade);
    nomeController.addListener(() => setState(() {}));
  }

  // Converte "08:00" para "8h 0m"
  String _converterParaIntervalo(String horario) {
    if (horario.contains('h')) return horario; // Já está no formato correto

    try {
      final partes = horario.split(':');
      if (partes.length == 2) {
        final horas = int.parse(partes[0]);
        final minutos = int.parse(partes[1]);
        return minutos > 0 ? '${horas}h ${minutos}m' : '${horas}h 0m';
      }
    } catch (_) {}
    return horario;
  }

  void _validarValidade() {
    setState(() {
      final resultado = _verificarValidadeVencida(validadeController.text);
      validadeVencida = resultado['vencida'] ?? false;
      mensagemErroValidade = resultado['mensagem'];
    });
  }

  Map<String, dynamic> _verificarValidadeVencida(String validade) {
    if (validade.isEmpty || validade.length < 10) {
      return {'vencida': false, 'mensagem': null};
    }

    try {
      final partes = validade.split('/');
      if (partes.length != 3) return {'vencida': false, 'mensagem': null};

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);

      if (ano < anoAtual) {
        return {
          'vencida': true,
          'mensagem': 'Ano deve ser $anoAtual ou posterior'
        };
      }

      if (dia < 1 || dia > 31 || mes < 1 || mes > 12) {
        return {'vencida': true, 'mensagem': 'Data inválida'};
      }

      final diasPorMes = [
        31,
        _ehBissexto(ano) ? 29 : 28,
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31
      ];
      if (dia > diasPorMes[mes - 1]) {
        return {'vencida': true, 'mensagem': 'Dia inválido para o mês $mes'};
      }

      final dataValidade = DateTime(ano, mes, dia);
      final hoje = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);

      if (dataValidade.isBefore(hoje)) {
        return {
          'vencida': true,
          'mensagem': 'Medicamento vencido - não é possível cadastrar'
        };
      }
    } catch (_) {
      return {'vencida': true, 'mensagem': 'Data inválida'};
    }
    return {'vencida': false, 'mensagem': null};
  }

  bool _ehBissexto(int ano) {
    if (ano % 400 == 0) return true;
    if (ano % 100 == 0) return false;
    if (ano % 4 == 0) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFF2C5282), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildCampoNome(),
                        const SizedBox(height: 16),
                        _buildCampoValidade(),
                        if (mensagemErroValidade != null) ...[
                          const SizedBox(height: 8),
                          _buildMensagemErro(mensagemErroValidade!),
                        ],
                        const SizedBox(height: 16),
                        _buildCampo(
                          asset: "assets/doses.png",
                          icon: Icons.medical_information,
                          titulo: "Primeira dose",
                          placeholder: "Primeiro horário (ex: 08:30)",
                          controller: primeiraDoseController,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            HoraInputFormatter(),
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCampoIntervalo(),
                        const SizedBox(height: 24),
                        _buildBotaoSalvar(),
                        if (isEdicao) ...[
                          const SizedBox(height: 12),
                          _buildBotaoExcluir(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2C5282),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child:
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text('voltar',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCampoNome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(
            "Nome do remédio", "assets/nome.png", Icons.medication),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: Column(
            children: [
              TextField(
                controller: nomeController,
                maxLength: 16,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(16),
                  RemoverAcentuacaoFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: "Ex: Paracetamol",
                  hintStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  counterText: "",
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  "${nomeController.text.length}/16 caracteres",
                  style: TextStyle(
                    fontSize: 11,
                    color: nomeController.text.length >= 16
                        ? Colors.red.shade600
                        : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampoValidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(
            "Validade", "assets/validade.png", Icons.calendar_today),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: TextField(
            controller: validadeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              DataInputFormatter(),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: "dd/mm/aaaa",
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampo({
    required String asset,
    required IconData icon,
    required String titulo,
    required String placeholder,
    required TextEditingController controller,
    required List<TextInputFormatter> formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(titulo, asset, icon),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // Campo especial para intervalo com formatação "Xh Ym"
  Widget _buildCampoIntervalo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(
            "Intervalo de doses", "assets/intervalo.png", Icons.access_time),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: TextField(
            controller: intervaloController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              IntervaloInputFormatter(), // Novo formatador!
              LengthLimitingTextInputFormatter(9), // "XXh XXm"
            ],
            decoration: InputDecoration(
              hintText: "Ex: 8h 0m (8 horas)",
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTituloCampo(String titulo, String asset, IconData iconFallback) {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          child: Image.asset(
            asset,
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              return Icon(iconFallback,
                  size: 32, color: const Color(0xFF2C5282));
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C5282)),
        ),
        const Text(" *",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
      ],
    );
  }

  Widget _buildMensagemErro(String mensagem) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        mensagem,
        style: const TextStyle(
            color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildBotaoSalvar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: validadeVencida ? null : _salvarMedicamento,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              validadeVencida ? Colors.grey.shade400 : const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: validadeVencida ? 0 : 2,
        ),
        child: Text(
          isEdicao ? 'Atualizar Medicamento' : 'Salvar Medicamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: validadeVencida ? Colors.grey.shade600 : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoExcluir() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _confirmarExclusao,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: const Text('Excluir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _salvarMedicamento() {
    List<String> erros = [];

    if (nomeController.text.trim().isEmpty) erros.add('Nome do remédio');
    if (validadeController.text.trim().isEmpty ||
        validadeController.text.length < 10) erros.add('Validade');
    if (primeiraDoseController.text.trim().isEmpty ||
        primeiraDoseController.text.length < 5) erros.add('Primeira dose');

    // Validação do intervalo (precisa ter pelo menos "Xh")
    if (intervaloController.text.trim().isEmpty ||
        !intervaloController.text.contains('h')) {
      erros.add('Intervalo de doses');
    }

    if (erros.isNotEmpty) {
      String mensagem = erros.length == 1
          ? 'Campo obrigatório: ${erros[0]}'
          : 'Campos obrigatórios: ${erros.join(', ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(mensagem),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3)),
      );
      return;
    }

    if (validadeVencida) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(mensagemErroValidade ?? 'Validade inválida!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final corEscolhida = widget.corPredefinida ??
        (isEdicao ? widget.medicamentoParaEditar!.cor : coresDisponiveis[0]);

    final medicamentoAtualizado = Medicamento(
      titulo: nomeController.text.trim(),
      dose: primeiraDoseController.text,
      horario: intervaloController.text, // Já está no formato "Xh Ym"
      validade: validadeController.text,
      cor: corEscolhida,
    );

    Navigator.pop(context, medicamentoAtualizado);
  }

  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
            'Deseja realmente excluir o medicamento "${widget.medicamentoParaEditar!.titulo}"?'),
        actions: [
          TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop()),
          TextButton(
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context, 'excluir');
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    validadeController.removeListener(_validarValidade);
    nomeController.removeListener(() {});
    nomeController.dispose();
    validadeController.dispose();
    primeiraDoseController.dispose();
    intervaloController.dispose();
    super.dispose();
  }
}

// ============================================================================
// FORMATADORES
// ============================================================================

// Formatador para remover acentuação
class RemoverAcentuacaoFormatter extends TextInputFormatter {
  static const Map<String, String> _mapaAcentos = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'Á': 'A',
    'À': 'A',
    'Ã': 'A',
    'Â': 'A',
    'Ä': 'A',
    'É': 'E',
    'È': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Õ': 'O',
    'Ô': 'O',
    'Ö': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ç': 'C',
  };

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String textoSemAcento = newValue.text
        .split('')
        .map((char) => _mapaAcentos[char] ?? char)
        .join('');
    return TextEditingValue(
      text: textoSemAcento,
      selection: TextSelection.collapsed(offset: textoSemAcento.length),
    );
  }
}

// Formatador para data (dd/mm/aaaa)
class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length >= 2) text = text.substring(0, 2) + '/' + text.substring(2);
    if (text.length >= 5) text = text.substring(0, 5) + '/' + text.substring(5);
    if (text.length > 10) text = text.substring(0, 10);
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// Formatador para hora (hh:mm)
class HoraInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length >= 1) {
      int primeiroDigito = int.parse(text[0]);
      if (primeiroDigito > 2) return oldValue;
    }

    if (text.length >= 2) {
      int horas = int.parse(text.substring(0, 2));
      if (horas > 23) return oldValue;
      text = text.substring(0, 2) + ':' + text.substring(2);
    }

    if (text.length >= 4) {
      String minutosStr = text.substring(3);
      if (minutosStr.isNotEmpty) {
        int primeiroDigitoMinuto = int.parse(minutosStr[0]);
        if (primeiroDigitoMinuto > 5) return oldValue;
      }
      if (minutosStr.length >= 2) {
        int minutos = int.parse(minutosStr.substring(0, 2));
        if (minutos > 59) return oldValue;
      }
    }

    if (text.length > 5) text = text.substring(0, 5);
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// 🆕 Formatador para INTERVALO (formato "Xh Ym")
class IntervaloInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limita a 4 dígitos (máximo: 23h 59m)
    if (text.length > 4) text = text.substring(0, 4);

    String formatted = '';

    if (text.isEmpty) {
      return TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }

    // Primeiro dígito (horas)
    if (text.length >= 1) {
      int primeiroDigito = int.parse(text[0]);
      if (primeiroDigito > 2) return oldValue; // Não permite horas > 23

      formatted = text[0];
    }

    // Segundo dígito (horas)
    if (text.length >= 2) {
      int horas = int.parse(text.substring(0, 2));
      if (horas > 23) return oldValue; // Bloqueia se horas > 23

      formatted = '${text.substring(0, 2)}h';
    }

    // Adiciona espaço antes dos minutos
    if (text.length >= 3) {
      formatted += ' ${text[2]}';
    }

    // Segundo dígito dos minutos
    if (text.length >= 4) {
      int primeiroDigitoMinuto = int.parse(text[2]);
      if (primeiroDigitoMinuto > 5) return oldValue; // Minutos não passam de 59

      int minutos = int.parse(text.substring(2, 4));
      if (minutos > 59) return oldValue;

      formatted = '${text.substring(0, 2)}h ${text.substring(2, 4)}m';
    }

    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}
