import 'package:flutter/material.dart';
import '../models/medicamento.dart';
import '../widgets/campo_formulario.dart';

class CadastroMedicamentoScreen extends StatefulWidget {
  final Medicamento? medicamentoParaEditar;
  final int? indiceEdicao;
  final Color? corPredefinida; // Nova propriedade para receber a cor

  const CadastroMedicamentoScreen({
    Key? key,
    this.medicamentoParaEditar,
    this.indiceEdicao,
    this.corPredefinida, // Adicionado o parâmetro
  }) : super(key: key);

  @override
  _CadastroMedicamentoScreenState createState() =>
      _CadastroMedicamentoScreenState();
}

class _CadastroMedicamentoScreenState extends State<CadastroMedicamentoScreen> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController quantidadeComprimidosController =
      TextEditingController();
  final TextEditingController validadeController = TextEditingController();
  final TextEditingController quantidadeDosesController =
      TextEditingController();
  final TextEditingController intervaloDosesController =
      TextEditingController();

  bool get isEdicao => widget.medicamentoParaEditar != null;

  // Variável para controlar se a validade está vencida
  bool validadeVencida = false;
  String? mensagemErroValidade;

  @override
  void initState() {
    super.initState();
    // Pré-preenche os campos se estiver editando
    if (isEdicao) {
      final med = widget.medicamentoParaEditar!;
      nomeController.text = med.titulo;
      validadeController.text = med.validade;
      intervaloDosesController.text = med.horario;
      // Agora a dose já está no formato de hora (hh:mm)
      quantidadeDosesController.text = med.dose;
    }

    // Adiciona listener para validar a validade em tempo real
    validadeController.addListener(_validarValidade);
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
      final partesData = validade.split('/');
      if (partesData.length != 3) {
        return {'vencida': false, 'mensagem': null};
      }

      final dia = int.parse(partesData[0]);
      final mes = int.parse(partesData[1]);
      final ano = int.parse(partesData[2]);

      // Validar se a data é válida
      if (dia < 1 || dia > 31 || mes < 1 || mes > 12 || ano < 1900) {
        return {'vencida': false, 'mensagem': null};
      }

      final dataValidade = DateTime(ano, mes, dia);
      final hoje = DateTime.now();
      final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

      if (dataValidade.isBefore(hojeSemHora)) {
        return {
          'vencida': true,
          'mensagem': 'Medicamento vencido - não é possível cadastrar',
        };
      }
    } catch (_) {
      return {'vencida': false, 'mensagem': null};
    }
    return {'vencida': false, 'mensagem': null};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'voltar',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Formulário
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2C5282),
                      width: 2,
                    ),
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
                      CampoFormulario(
                        iconeWidget: Image.asset(
                          "assets/nome.png",
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.medication,
                              size: 32,
                              color: const Color(0xFF2C5282),
                            );
                          },
                        ),
                        titulo: "Nome do remédio",
                        placeholder: "Ex: Paracetamol 500mg",
                        controller: nomeController,
                        iconeFallback: Icons.medication,
                      ),
                      const SizedBox(height: 8),
                      CampoFormulario(
                        iconeWidget: Image.asset(
                          "assets/frasco.png",
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.grid_view,
                              size: 32,
                              color: const Color(0xFF2C5282),
                            );
                          },
                        ),
                        titulo: "Quantidade de comprimidos",
                        placeholder: "Número",
                        controller: quantidadeComprimidosController,
                        iconeFallback: Icons.grid_view,
                        keyboardType: TextInputType.number,
                        tipoValidacao: 'numero',
                      ),
                      const SizedBox(height: 8),
                      CampoFormulario(
                        iconeWidget: Image.asset(
                          "assets/validade.png",
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.calendar_today,
                              size: 32,
                              color: const Color(0xFF2C5282),
                            );
                          },
                        ),
                        titulo: "Validade",
                        placeholder: "dd/mm/aaaa",
                        controller: validadeController,
                        iconeFallback: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        tipoValidacao: 'data',
                      ),
                      // Aviso de validade vencida
                      if (mensagemErroValidade != null) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            mensagemErroValidade!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      CampoFormulario(
                        iconeWidget: Image.asset(
                          "assets/doses.png",
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.medical_information,
                              size: 32,
                              color: const Color(0xFF2C5282),
                            );
                          },
                        ),
                        titulo: "Primeira dose",
                        placeholder: "Horário - (ex: 08:30)",
                        controller: quantidadeDosesController,
                        iconeFallback: Icons.medical_information,
                        keyboardType: TextInputType.number,
                        tipoValidacao: 'hora',
                      ),
                      const SizedBox(height: 8),
                      CampoFormulario(
                        iconeWidget: Image.asset(
                          "assets/intervalo.png",
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.access_time,
                              size: 32,
                              color: const Color(0xFF2C5282),
                            );
                          },
                        ),
                        titulo: "Intervalo de doses",
                        placeholder: "Intervalo - (ex: 08:00)",
                        controller: intervaloDosesController,
                        iconeFallback: Icons.access_time,
                        keyboardType: TextInputType.number,
                        tipoValidacao: 'hora',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              validadeVencida
                                  ? null
                                  : () {
                                    _salvarMedicamento();
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                validadeVencida
                                    ? Colors.grey.shade400
                                    : const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: validadeVencida ? 0 : 2,
                          ),
                          child: Text(
                            isEdicao
                                ? 'Atualizar Medicamento'
                                : 'Salvar Medicamento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color:
                                  validadeVencida
                                      ? Colors.grey.shade600
                                      : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Botão de excluir só aparece na edição
                      if (isEdicao) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              _confirmarExclusao();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade300,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Excluir',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _salvarMedicamento() {
    if (nomeController.text.isEmpty ||
        quantidadeComprimidosController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha pelo menos o nome e a quantidade!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Impede cadastro se a validade estiver vencida
    if (validadeVencida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível cadastrar medicamento vencido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Usar a cor predefinida (sequencial) ou manter a cor original na edição
    final corEscolhida =
        widget.corPredefinida ??
        (isEdicao
            ? widget.medicamentoParaEditar!.cor
            : coresDisponiveis[0]); // Fallback para azul

    final medicamentoAtualizado = Medicamento(
      titulo: nomeController.text,
      dose:
          quantidadeDosesController.text.isNotEmpty
              ? quantidadeDosesController.text
              : "08:00",
      horario:
          intervaloDosesController.text.isNotEmpty
              ? intervaloDosesController.text
              : '08:00',
      validade: validadeController.text,
      cor: corEscolhida,
    );

    Navigator.pop(context, medicamentoAtualizado);
  }

  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Text(
            'Deseja realmente excluir o medicamento "${widget.medicamentoParaEditar!.titulo}"?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
                Navigator.pop(
                  context,
                  'excluir',
                ); // Retorna para a tela anterior
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    validadeController.removeListener(_validarValidade);
    nomeController.dispose();
    quantidadeComprimidosController.dispose();
    validadeController.dispose();
    quantidadeDosesController.dispose();
    intervaloDosesController.dispose();
    super.dispose();
  }
}
