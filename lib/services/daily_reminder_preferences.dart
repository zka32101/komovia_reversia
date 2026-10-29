import 'package:shared_preferences/shared_preferences.dart';

/// `SettingsScreen`がテスト時に実際の`SharedPreferences`を介さずに
/// 差し替えられるようにするための最小インターフェース。
abstract class DailyReminderPreferencesLike {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool value);
  Future<int> getHour();
  Future<int> getMinute();
  Future<void> setTime(int hour, int minute);
}

/// デイリーリマインダー（「今日の1局」を知らせる端末ローカル通知）の
/// オン/オフ・時刻設定の永続化 - `OnboardingService`と同じく
/// `SharedPreferences`のみを使う端末ローカルな設定（アカウントデータ
/// ではない）。
class DailyReminderPreferences implements DailyReminderPreferencesLike {
  static const _enabledKey = 'daily_reminder_enabled';
  static const _hourKey = 'daily_reminder_hour';
  static const _minuteKey = 'daily_reminder_minute';

  static const int defaultHour = 19;
  static const int defaultMinute = 0;

  @override
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  @override
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  @override
  Future<int> getHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hourKey) ?? defaultHour;
  }

  @override
  Future<int> getMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minuteKey) ?? defaultMinute;
  }

  @override
  Future<void> setTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }
}
