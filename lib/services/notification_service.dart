import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medicamento.dart';

/// Serviço responsável por gerenciar notificações de medicamentos
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
  }

  /// Solicita permissão para notificações (necessário no Android 13+)
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
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
      return granted ?? false;
    }

    return true;
  }

  /// Agenda notificações para um medicamento
  /// Agenda as próximas 6 doses
  Future<void> agendarNotificacoes(Medicamento medicamento, int indice) async {
    if (!_initialized) await initialize();

    // Cancela notificações antigas deste medicamento
    await cancelarNotificacoesMedicamento(indice);

    try {
      // Parse da primeira dose
      final partesHorario = medicamento.dose.split(':');
      if (partesHorario.length != 2) return;

      final horaInicial = int.parse(partesHorario[0]);
      final minutoInicial = int.parse(partesHorario[1]);

      // Parse do intervalo
      final partesIntervalo = medicamento.horario.split(':');
      if (partesIntervalo.length != 2) return;

      final horasIntervalo = int.parse(partesIntervalo[0]);
      final minutosIntervalo = int.parse(partesIntervalo[1]);

      final intervaloEmMinutos = (horasIntervalo * 60) + minutosIntervalo;
      if (intervaloEmMinutos == 0) return;

      // Agenda as próximas 6 doses
      final agora = DateTime.now();
      DateTime proximaDose = DateTime(
        agora.year,
        agora.month,
        agora.day,
        horaInicial,
        minutoInicial,
      );

      // Se a primeira dose já passou hoje, começa do próximo horário
      if (proximaDose.isBefore(agora)) {
        final diferencaMinutos = agora.difference(proximaDose).inMinutes;
        final dosesPassadas = (diferencaMinutos / intervaloEmMinutos).floor();
        proximaDose = proximaDose.add(
          Duration(minutes: (dosesPassadas + 1) * intervaloEmMinutos),
        );
      }

      // Agenda 6 notificações
      for (int i = 0; i < 6; i++) {
        final notificationId =
            (indice * 100) + i; // ID único por medicamento e dose

        await _notifications.zonedSchedule(
          notificationId,
          'Hora do medicamento! 💊',
          '${medicamento.titulo} - Tome sua dose agora',
          tz.TZDateTime.from(proximaDose, tz.local),
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

        // Próxima dose
        proximaDose = proximaDose.add(Duration(minutes: intervaloEmMinutos));
      }

      print('✅ Agendadas 6 notificações para ${medicamento.titulo}');
    } catch (e) {
      print('❌ Erro ao agendar notificações: $e');
    }
  }

  /// Cancela todas as notificações de um medicamento específico
  Future<void> cancelarNotificacoesMedicamento(int indice) async {
    for (int i = 0; i < 6; i++) {
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
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Callback quando usuário toca na notificação
  void _onNotificationTap(NotificationResponse response) {
    print('Notificação tocada: ${response.payload}');
    // Aqui você pode navegar para uma tela específica se necessário
  }

  /// Lista todas as notificações pendentes (para debug)
  Future<void> listarNotificacoesPendentes() async {
    final pendentes = await _notifications.pendingNotificationRequests();
    print('📋 Notificações pendentes: ${pendentes.length}');
    for (var notif in pendentes) {
      print('  - ID: ${notif.id}, Título: ${notif.title}');
    }
  }
}
