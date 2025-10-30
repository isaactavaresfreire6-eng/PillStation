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
  /// Agenda as próximas 7 doses com validação robusta
  Future<void> agendarNotificacoes(Medicamento medicamento, int indice) async {
    if (!_initialized) await initialize();

    // Cancela notificações antigas deste medicamento
    await cancelarNotificacoesMedicamento(indice);

    try {
      print('\n🔔 Agendando notificações para: ${medicamento.titulo}');

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
          '⏰ Primeira dose: ${horaInicial.toString().padLeft(2, '0')}:${minutoInicial.toString().padLeft(2, '0')}');
      print(
          '⏱️ Intervalo: ${horasIntervalo}h ${minutosIntervalo}m ($intervaloEmMinutos minutos)');

      // Obtém data/hora atual
      final agora = tz.TZDateTime.now(tz.local);
      print(
          '🕐 Hora atual: ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}');

      // Cria data/hora da primeira dose de HOJE
      var proximaDose = tz.TZDateTime(
        tz.local,
        agora.year,
        agora.month,
        agora.day,
        horaInicial,
        minutoInicial,
      );

      // Se a primeira dose já passou hoje, calcula a próxima dose válida
      if (proximaDose.isBefore(agora) ||
          proximaDose.difference(agora).inMinutes < 1) {
        final diferencaMinutos = agora.difference(proximaDose).inMinutes.abs();
        final dosesPassadas = (diferencaMinutos / intervaloEmMinutos).ceil();
        proximaDose = proximaDose.add(
          Duration(minutes: dosesPassadas * intervaloEmMinutos),
        );
        print(
            '⏩ Primeira dose já passou. Próxima dose: ${proximaDose.hour.toString().padLeft(2, '0')}:${proximaDose.minute.toString().padLeft(2, '0')}');
      }

      // Agenda 7 notificações (1 semana aproximadamente se for intervalo de 24h)
      int notificacoesAgendadas = 0;
      const int totalNotificacoes = 7;

      for (int i = 0; i < totalNotificacoes; i++) {
        final notificationId = (indice * 100) + i;

        // Só agenda se for no futuro (pelo menos 1 minuto)
        if (proximaDose.isAfter(agora) &&
            proximaDose.difference(agora).inMinutes >= 1) {
          await _notifications.zonedSchedule(
            notificationId,
            'Hora do medicamento! 💊',
            '${medicamento.titulo} - Tome sua dose agora',
            proximaDose,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );

          final dataFormatada =
              '${proximaDose.day.toString().padLeft(2, '0')}/${proximaDose.month.toString().padLeft(2, '0')}';
          final horaFormatada =
              '${proximaDose.hour.toString().padLeft(2, '0')}:${proximaDose.minute.toString().padLeft(2, '0')}';

          print(
              '  ✅ Dose ${i + 1}: $dataFormatada às $horaFormatada (ID: $notificationId)');
          notificacoesAgendadas++;
        } else {
          print('  ⏭️ Dose ${i + 1}: Pulada (muito próxima ou no passado)');
        }

        // Próxima dose
        proximaDose = proximaDose.add(Duration(minutes: intervaloEmMinutos));
      }

      print(
          '✅ Total agendadas: $notificacoesAgendadas/$totalNotificacoes notificações para ${medicamento.titulo}\n');

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
      // Cancela até 10 notificações por segurança
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
    // Aqui você pode adicionar navegação para tela específica
  }

  /// Lista todas as notificações pendentes (para debug)
  Future<void> listarNotificacoesPendentes() async {
    final pendentes = await _notifications.pendingNotificationRequests();
    print('📋 Notificações pendentes: ${pendentes.length}');
    if (pendentes.isEmpty) {
      print('  ⚠️ Nenhuma notificação agendada!');
    } else {
      for (var notif in pendentes) {
        print(
            '  📌 ID: ${notif.id}, Título: ${notif.title}, Corpo: ${notif.body}');
      }
    }
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
}
