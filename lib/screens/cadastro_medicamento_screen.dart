import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medicamento.dart';

/// Tela para cadastro e edição de medicamentos
/// Permite criar novos medicamentos ou editar existentes
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
  // Controladores dos campos de texto
  final _nomeController = TextEditingController();
  final _validadeController = TextEditingController();
  final _primeiraDoseController = TextEditingController();
  final _intervaloController = TextEditingController();

  // Estados de validação
  bool _validadeVencida = false;
  String? _mensagemErroValidade;

  // Controle de mudança do horário da primeira dose
  String? _primeiraDoseOriginal;
  bool _primeiraDoseFoiAlterada = false;

  // Constantes e getters utilitários
  static const int _maxCaracteresNome = 16;
  static const int _maxCaracteresData = 10;
  static const int _maxCaracteresHora = 5;

  int get _anoAtual => DateTime.now().year;
  bool get _isEdicao => widget.medicamentoParaEditar != null;

  @override
  void initState() {
    super.initState();
    _inicializarCampos();
    _configurarListeners();
  }

  /// Inicializa os campos com dados do medicamento em edição
  void _inicializarCampos() {
    if (_isEdicao) {
      final med = widget.medicamentoParaEditar!;
      _nomeController.text = med.titulo;
      _validadeController.text = med.validade;
      _intervaloController.text = med.horario;
      _primeiraDoseController.text = med.dose;

      // Armazena o valor original da primeira dose
      _primeiraDoseOriginal = med.dose;
    }
  }

  /// Configura os listeners para validação em tempo real
  void _configurarListeners() {
    _validadeController.addListener(_validarValidade);
    _nomeController.addListener(() => setState(() {}));

    // Listener para detectar mudanças na primeira dose
    _primeiraDoseController.addListener(() {
      if (_isEdicao) {
        setState(() {
          _primeiraDoseFoiAlterada =
              _primeiraDoseController.text != _primeiraDoseOriginal;
        });
      }
    });
  }

  /// Valida a data de validade em tempo real
  void _validarValidade() {
    final resultado = _verificarValidadeVencida(_validadeController.text);
    setState(() {
      _validadeVencida = resultado['vencida'] ?? false;
      _mensagemErroValidade = resultado['mensagem'];
    });
  }

  /// Verifica se a data de validade é válida e não está vencida
  /// Retorna um Map com 'vencida' (bool) e 'mensagem' (String?)
  Map<String, dynamic> _verificarValidadeVencida(String validade) {
    // Valida formato básico
    if (validade.isEmpty || validade.length < _maxCaracteresData) {
      return {'vencida': false, 'mensagem': null};
    }

    try {
      final partes = validade.split('/');
      if (partes.length != 3) {
        return {'vencida': false, 'mensagem': null};
      }

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);

      // Valida ano mínimo
      if (ano < _anoAtual) {
        return {
          'vencida': true,
          'mensagem': 'Ano deve ser $_anoAtual ou posterior'
        };
      }

      // Valida ranges básicos de dia e mês
      if (dia < 1 || dia > 31 || mes < 1 || mes > 12) {
        return {'vencida': true, 'mensagem': 'Data inválida'};
      }

      // Valida dia conforme o mês
      final diasPorMes = _obterDiasPorMes(ano);
      if (dia > diasPorMes[mes - 1]) {
        return {'vencida': true, 'mensagem': 'Dia inválido para o mês $mes'};
      }

      // Valida se a data não está no passado
      final dataValidade = DateTime(ano, mes, dia);
      final hoje = _obterDataAtualSemHora();

      if (dataValidade.isBefore(hoje)) {
        return {
          'vencida': true,
          'mensagem': 'Medicamento vencido - não é possível cadastrar'
        };
      }

      return {'vencida': false, 'mensagem': null};
    } catch (_) {
      return {'vencida': true, 'mensagem': 'Data inválida'};
    }
  }

  /// Retorna lista com dias por mês considerando ano bissexto
  List<int> _obterDiasPorMes(int ano) {
    return [
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
  }

  /// Verifica se o ano é bissexto
  bool _ehBissexto(int ano) {
    if (ano % 400 == 0) return true;
    if (ano % 100 == 0) return false;
    return ano % 4 == 0;
  }

  /// Retorna a data atual sem hora para comparações
  DateTime _obterDataAtualSemHora() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
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
                  child: _buildFormulario(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o cabeçalho com botão de voltar
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
          const Text(
            'voltar',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Constrói o formulário principal com todos os campos
  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C5282), width: 2),
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
          if (_mensagemErroValidade != null) ...[
            const SizedBox(height: 8),
            _buildMensagemErro(_mensagemErroValidade!),
          ],
          const SizedBox(height: 16),
          _buildCampoHorario(
            asset: "assets/doses.png",
            icon: Icons.medical_information,
            titulo: "Primeira dose",
            placeholder: "Horário (ex: 08:30)",
            controller: _primeiraDoseController,
          ),
          // Indicador de comportamento ao atualizar
          if (_isEdicao) ...[
            const SizedBox(height: 8),
            _buildAvisoAtualizacao(),
          ],
          const SizedBox(height: 16),
          _buildCampoHorario(
            asset: "assets/intervalo.png",
            icon: Icons.access_time,
            titulo: "Intervalo de doses",
            placeholder: "Intervalo (ex: 08:00)",
            controller: _intervaloController,
          ),
          const SizedBox(height: 24),
          _buildBotaoSalvar(),
          if (_isEdicao) ...[
            const SizedBox(height: 12),
            _buildBotaoExcluir(),
          ],
        ],
      ),
    );
  }

  /// Aviso sobre o comportamento da primeira dose ao atualizar
  Widget _buildAvisoAtualizacao() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primeiraDoseFoiAlterada
            ? Colors.blue.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _primeiraDoseFoiAlterada
              ? Colors.blue.shade200
              : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _primeiraDoseFoiAlterada ? Icons.info_outline : Icons.schedule,
            size: 20,
            color: _primeiraDoseFoiAlterada
                ? Colors.blue.shade700
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _primeiraDoseFoiAlterada
                  ? 'Nova primeira dose será no horário definido'
                  : 'Primeira dose será no horário atual da atualização',
              style: TextStyle(
                fontSize: 12,
                color: _primeiraDoseFoiAlterada
                    ? Colors.blue.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o campo de nome com contador de caracteres
  Widget _buildCampoNome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(
            "Nome do remédio", "assets/nome.png", Icons.medication),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: Column(
            children: [
              TextField(
                controller: _nomeController,
                maxLength: _maxCaracteresNome,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_maxCaracteresNome),
                  RemoverAcentuacaoFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: "Ex: Paracetamol",
                  hintStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  counterText: "", // Remove contador padrão
                ),
              ),
              // Contador customizado
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "${_nomeController.text.length}/$_maxCaracteresNome caracteres",
                    style: TextStyle(
                      fontSize: 11,
                      color: _nomeController.text.length >= _maxCaracteresNome
                          ? Colors.red.shade600
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Constrói o campo de validade com formatação de data
  Widget _buildCampoValidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(
            "Validade", "assets/validade.png", Icons.calendar_today),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: TextField(
            controller: _validadeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              DataInputFormatter(),
              LengthLimitingTextInputFormatter(_maxCaracteresData),
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

  /// Constrói campos de horário (primeira dose e intervalo)
  Widget _buildCampoHorario({
    required String asset,
    required IconData icon,
    required String titulo,
    required String placeholder,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloCampo(titulo, asset, icon),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              HoraInputFormatter(),
              LengthLimitingTextInputFormatter(_maxCaracteresHora),
            ],
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

  /// Constrói o título do campo com ícone e indicador obrigatório
  Widget _buildTituloCampo(String titulo, String asset, IconData iconFallback) {
    return Row(
      children: [
        SizedBox(
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
            color: Color(0xFF2C5282),
          ),
        ),
        const Text(
          " *",
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ],
    );
  }

  /// Exibe mensagem de erro de validação
  Widget _buildMensagemErro(String mensagem) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        mensagem,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Constrói o botão de salvar/atualizar
  Widget _buildBotaoSalvar() {
    final bool habilitado = !_validadeVencida;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: habilitado ? _salvarMedicamento : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              habilitado ? const Color(0xFF4CAF50) : Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: habilitado ? 2 : 0,
        ),
        child: Text(
          _isEdicao ? 'Atualizar Medicamento' : 'Salvar Medicamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: habilitado ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  /// Constrói o botão de excluir (apenas em modo edição)
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
        child: const Text(
          'Excluir',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Valida e salva o medicamento
  void _salvarMedicamento() {
    // Valida campos obrigatórios
    final erros = _validarCamposObrigatorios();

    if (erros.isNotEmpty) {
      _mostrarErroValidacao(erros);
      return;
    }

    // Valida validade novamente
    if (_validadeVencida) {
      _mostrarSnackBar(
        _mensagemErroValidade ?? 'Validade inválida!',
        Colors.red,
      );
      return;
    }

    // Cria medicamento e retorna
    if (_isEdicao) {
      // Retorna Map com medicamento e flag de mudança da primeira dose
      final resultado = {
        'medicamento': _criarMedicamento(),
        'primeiraDoseMudou': _primeiraDoseFoiAlterada,
      };
      Navigator.pop(context, resultado);
    } else {
      // Para novo cadastro, retorna apenas o medicamento
      Navigator.pop(context, _criarMedicamento());
    }
  }

  /// Valida se todos os campos obrigatórios estão preenchidos
  List<String> _validarCamposObrigatorios() {
    final erros = <String>[];

    if (_nomeController.text.trim().isEmpty) {
      erros.add('Nome do remédio');
    }
    if (_validadeController.text.trim().isEmpty ||
        _validadeController.text.length < _maxCaracteresData) {
      erros.add('Validade');
    }
    if (_primeiraDoseController.text.trim().isEmpty ||
        _primeiraDoseController.text.length < _maxCaracteresHora) {
      erros.add('Primeira dose');
    }
    if (_intervaloController.text.trim().isEmpty ||
        _intervaloController.text.length < _maxCaracteresHora) {
      erros.add('Intervalo de doses');
    }

    return erros;
  }

  /// Mostra mensagem de erro de validação
  void _mostrarErroValidacao(List<String> erros) {
    final mensagem = erros.length == 1
        ? 'Campo obrigatório: ${erros[0]}'
        : 'Campos obrigatórios: ${erros.join(', ')}';

    _mostrarSnackBar(mensagem, Colors.red);
  }

  /// Exibe SnackBar com mensagem
  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Cria instância de Medicamento com os dados do formulário
  Medicamento _criarMedicamento() {
    final cor = widget.corPredefinida ??
        (_isEdicao ? widget.medicamentoParaEditar!.cor : coresDisponiveis[0]);

    return Medicamento(
      titulo: _nomeController.text.trim(),
      dose: _primeiraDoseController.text,
      horario: _intervaloController.text,
      validade: _validadeController.text,
      cor: cor,
    );
  }

  /// Confirma exclusão do medicamento com diálogo
  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Deseja realmente excluir o medicamento "${widget.medicamentoParaEditar!.titulo}"?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
    // Remove listeners antes de descartar
    _validadeController.removeListener(_validarValidade);
    _nomeController.removeListener(() {});
    _primeiraDoseController.removeListener(() {});

    // Descarta controladores
    _nomeController.dispose();
    _validadeController.dispose();
    _primeiraDoseController.dispose();
    _intervaloController.dispose();

    super.dispose();
  }
}

// ============================================================================
// FORMATADORES DE INPUT
// ============================================================================

/// Formatador que remove acentuação de caracteres
/// Útil para padronizar nomes de medicamentos
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
    final textoSemAcento = newValue.text
        .split('')
        .map((char) => _mapaAcentos[char] ?? char)
        .join('');

    return TextEditingValue(
      text: textoSemAcento,
      selection: TextSelection.collapsed(offset: textoSemAcento.length),
    );
  }
}

/// Formatador para data no formato dd/mm/aaaa
/// Adiciona barras automaticamente enquanto o usuário digita
class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove caracteres não numéricos
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Adiciona primeira barra após o dia
    if (text.length >= 2) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }

    // Adiciona segunda barra após o mês
    if (text.length >= 5) {
      text = '${text.substring(0, 5)}/${text.substring(5)}';
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

/// Formatador para hora no formato hh:mm
/// Valida horas (0-23) e minutos (0-59) em tempo real
class HoraInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove caracteres não numéricos
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Valida primeiro dígito da hora (máximo 2)
    if (text.length >= 1) {
      int primeiroDigito = int.parse(text[0]);
      if (primeiroDigito > 2) return oldValue;
    }

    // Valida hora completa (máximo 23) e adiciona dois pontos
    if (text.length >= 2) {
      int horas = int.parse(text.substring(0, 2));
      if (horas > 23) return oldValue;
      text = '${text.substring(0, 2)}:${text.substring(2)}';
    }

    // Valida minutos
    if (text.length >= 4) {
      String minutosStr = text.substring(3);

      // Valida primeiro dígito dos minutos (máximo 5)
      if (minutosStr.isNotEmpty) {
        int primeiroDigitoMinuto = int.parse(minutosStr[0]);
        if (primeiroDigitoMinuto > 5) return oldValue;
      }

      // Valida minutos completos (máximo 59)
      if (minutosStr.length >= 2) {
        int minutos = int.parse(minutosStr.substring(0, 2));
        if (minutos > 59) return oldValue;
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
