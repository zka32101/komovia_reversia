import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 「今日の1局」用のデイリーリマインダー通知をスケジュール/解除する -
/// project-015の`local_notification_service.dart`と同じ役割（完全に
/// 端末上のみ、サーバー/Firebaseは関与しない）。あえて単純な設計: 固定の
/// 時刻を1つだけ持ち、通知発火時に「今日の1局」を既に解いたかどうかを
/// 見ることはしない（`flutter_local_notifications`は事前にスケジュール
/// するため、発火時にアプリの実行中の状態を参照できない）。
///
/// `AndroidScheduleMode.inexactAllowWhileIdle`を使うため、Android 12+の
/// 「正確なアラーム」権限は不要（数分遅れて発火する可能性があるが、この
/// 種のリマインダーには十分許容できるトレードオフ）。
class LocalNotificationService {
  static const int _dailyReminderId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'デイリーリマインダー';

  LocalNotificationService._();
  static final LocalNotificationService _instance = LocalNotificationService._();
  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // timezoneパッケージのデフォルト(UTC)にフォールバックする - 通知
      // 自体は発火するが、ユーザーが選んだ正確なローカル時刻とは
      // 限らない。
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  /// OSレベルの通知権限をリクエストする（Android 13+/iOS）。許可された
  /// 場合（またはそもそも確認を求めないプラットフォームの場合）true。
  Future<bool> requestPermission() async {
    await _ensureInitialized();

    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// [hour]:[minute]（ローカル時刻）に毎日繰り返し発火する通知をスケジ
  /// ュールする。既存のスケジュールは置き換える。
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    await _ensureInitialized();

    final next = _nextInstanceOf(hour, minute);
    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Komovia Reversia',
      '今日の1局はまだです。挑戦しましょう！',
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _ensureInitialized();
    await _plugin.cancel(_dailyReminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
