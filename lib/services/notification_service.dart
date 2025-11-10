import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medicamento.dart';

/// Serviço responsável por gerenciar notificações de medicamentos
/// LÓGICA SIMPLIFICADA: Sem SharedPreferences, tudo baseado em cálculo de tempo
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    if (_initialized) return;

    print('🔔 Inicializando serviço de notificações...');

    try {
      // Inicializa timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

      // Configurações Android
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configurações iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _initialized = true;
      print('✅ Notificações inicializadas com sucesso!');
    } catch (e, stackTrace) {
      print('❌ Erro ao inicializar notificações: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Solicita permissão para notificações (necessário no Android 13+)
  Future<bool> requestPermissions() async {
    print('📱 Solicitando permissões de notificação...');

    try {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        print(
            '✅ Permissão Android: ${granted == true ? "Concedida" : "Negada"}');
        return granted ?? false;
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('✅ Permissão iOS: ${granted == true ? "Concedida" : "Negada"}');
        return granted ?? false;
      }

      return true;
    } catch (e) {
      print('❌ Erro ao solicitar permissões: $e');
      return false;
    }
  }

  /// Agenda notificações para um medicamento
  /// LÓGICA CORRIGIDA: Agenda sempre 6 doses a partir da primeira dose configurada
  Future<void> agendarNotificacoes(Medicamento medicamento, int indice) async {
    if (!_initialized) await initialize();

    // Cancela notificações antigas deste medicamento
    await cancelarNotificacoesMedicamento(indice);

    try {
      print('\n🔔 ========================================');
      print('🔔 AGENDANDO NOTIFICAÇÕES: ${medicamento.titulo}');
      print('🔔 ========================================');

      // Parse da primeira dose
      final partesHorario = medicamento.dose.split(':');
      if (partesHorario.length != 2) {
        print('❌ Erro: Formato de hora inválido: ${medicamento.dose}');
        return;
      }

      final horaInicial = int.tryParse(partesHorario[0]);
      final minutoInicial = int.tryParse(partesHorario[1]);

      if (horaInicial == null || minutoInicial == null) {
        print('❌ Erro: Hora ou minuto inválido');
        return;
      }

      if (horaInicial < 0 ||
          horaInicial > 23 ||
          minutoInicial < 0 ||
          minutoInicial > 59) {
        print('❌ Erro: Hora fora do intervalo válido (00:00 - 23:59)');
        return;
      }

      // Parse do intervalo
      final partesIntervalo = medicamento.horario.split(':');
      if (partesIntervalo.length != 2) {
        print('❌ Erro: Formato de intervalo inválido: ${medicamento.horario}');
        return;
      }

      final horasIntervalo = int.tryParse(partesIntervalo[0]);
      final minutosIntervalo = int.tryParse(partesIntervalo[1]);

      if (horasIntervalo == null || minutosIntervalo == null) {
        print('❌ Erro: Intervalo de horas ou minutos inválido');
        return;
      }

      final intervaloEmMinutos = (horasIntervalo * 60) + minutosIntervalo;

      if (intervaloEmMinutos <= 0) {
        print('❌ Erro: Intervalo não pode ser zero ou negativo');
        return;
      }

      if (intervaloEmMinutos < 30) {
        print(
            '⚠️ Aviso: Intervalo muito curto (${intervaloEmMinutos} min). Mínimo recomendado: 30 min');
      }

      print(
          '⏰ Primeira dose configurada: ${horaInicial.toString().padLeft(2, '0')}:${minutoInicial.toString().padLeft(2, '0')}');
      print(
          '⏱️ Intervalo: ${horasIntervalo}h ${minutosIntervalo}m ($intervaloEmMinutos minutos)');

      // Obtém data/hora atual
      final agora = tz.TZDateTime.now(tz.local);
      print(
          '🕐 Hora atual: ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}');

      // Cria data/hora da primeira dose de HOJE
      var primeiraDose = tz.TZDateTime(
        tz.local,
        agora.year,
        agora.month,
        agora.day,
        horaInicial,
        minutoInicial,
      );

      // Se a primeira dose já passou hoje, ajusta para a próxima dose futura
      if (primeiraDose.isBefore(agora) ||
          primeiraDose.difference(agora).inMinutes < 1) {
        final minutosPassados = agora.difference(primeiraDose).inMinutes;

        // Calcula quantas doses já passaram
        final dosesPassadas = (minutosPassados / intervaloEmMinutos).floor();

        // Avança para a próxima dose que ainda não passou
        primeiraDose = primeiraDose.add(
          Duration(minutes: (dosesPassadas + 1) * intervaloEmMinutos),
        );

        print(
            '⏩ Primeira dose já passou. Próxima dose futura: ${primeiraDose.hour.toString().padLeft(2, '0')}:${primeiraDose.minute.toString().padLeft(2, '0')}');
      } else {
        print('✅ Primeira dose ainda não chegou hoje');
      }

      // Agenda exatamente 6 notificações (Dose 1/6 até 6/6)
      int notificacoesAgendadas = 0;
      const int TOTAL_DOSES = 6;

      print('\n📋 AGENDANDO 6 DOSES:');
      print('─────────────────────────────────────────');

      for (int i = 0; i < TOTAL_DOSES; i++) {
        // Calcula o horário desta dose
        final horarioDose = primeiraDose.add(
          Duration(minutes: i * intervaloEmMinutos),
        );

        final notificationId = (indice * 100) + i;

        // Só agenda se for no futuro (pelo menos 1 minuto)
        if (horarioDose.isAfter(agora) &&
            horarioDose.difference(agora).inMinutes >= 1) {
          // Número da dose para notificação (1/6, 2/6, ..., 6/6)
          final doseNumero = i + 1;

          await _notifications.zonedSchedule(
            notificationId,
            '💊 Hora do medicamento! (Dose $doseNumero/$TOTAL_DOSES)',
            '${medicamento.titulo} - Tome sua dose agora',
            horarioDose,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );

          final dataFormatada =
              '${horarioDose.day.toString().padLeft(2, '0')}/${horarioDose.month.toString().padLeft(2, '0')}';
          final horaFormatada =
              '${horarioDose.hour.toString().padLeft(2, '0')}:${horarioDose.minute.toString().padLeft(2, '0')}';

          print(
              '  ✅ Dose $doseNumero/6: $dataFormatada às $horaFormatada (ID: $notificationId)');
          notificacoesAgendadas++;
        } else {
          final horaFormatada =
              '${horarioDose.hour.toString().padLeft(2, '0')}:${horarioDose.minute.toString().padLeft(2, '0')}';
          print('  ⏭️ Dose ${i + 1}/6: $horaFormatada (Pulada - no passado)');
        }
      }

      print('─────────────────────────────────────────');
      print(
          '✅ Total agendadas: $notificacoesAgendadas/$TOTAL_DOSES notificações');
      print('🔔 ========================================\n');

      // Lista notificações pendentes para debug
      await listarNotificacoesPendentes();
    } catch (e, stackTrace) {
      print('❌ Erro ao agendar notificações: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Cancela todas as notificações de um medicamento específico
  Future<void> cancelarNotificacoesMedicamento(int indice) async {
    for (int i = 0; i < 10; i++) {
      final notificationId = (indice * 100) + i;
      await _notifications.cancel(notificationId);
    }
    print('🗑️ Notificações canceladas para medicamento índice $indice');
  }

  /// Cancela todas as notificações
  Future<void> cancelarTodasNotificacoes() async {
    await _notifications.cancelAll();
    print('🗑️ Todas as notificações canceladas');
  }

  /// Detalhes da notificação (som, vibração, etc)
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'medicamento_channel',
        'Lembretes de Medicamentos',
        channelDescription: 'Notificações para lembrar de tomar medicamentos',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
        fullScreenIntent: true,
        ticker: 'Hora do medicamento',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Callback quando usuário toca na notificação
  void _onNotificationTap(NotificationResponse response) {
    print('👆 Notificação tocada: ${response.payload}');
  }

  /// Lista todas as notificações pendentes (para debug)
  Future<void> listarNotificacoesPendentes() async {
    final pendentes = await _notifications.pendingNotificationRequests();
    print('📋 ═══════════════════════════════════════');
    print('📋 NOTIFICAÇÕES PENDENTES: ${pendentes.length}');
    print('📋 ═══════════════════════════════════════');

    if (pendentes.isEmpty) {
      print('  ⚠️ Nenhuma notificação agendada!');
    } else {
      for (var notif in pendentes) {
        print('  📌 ID: ${notif.id}');
        print('     Título: ${notif.title}');
        print('     Corpo: ${notif.body}');
        print('     ───────────────────────────────────');
      }
    }
    print('📋 ═══════════════════════════════════════\n');
  }

  /// Testa notificação imediata (para debug)
  Future<void> testarNotificacaoImediata(String titulo, String mensagem) async {
    if (!_initialized) await initialize();

    print('🧪 Testando notificação imediata...');

    await _notifications.show(
      999,
      titulo,
      mensagem,
      _notificationDetails(),
    );

    print('✅ Notificação de teste enviada!');
  }

  void enviarNotificacaoImediata(String titulo, dosesTomadas, int limite_doses) {}
}
