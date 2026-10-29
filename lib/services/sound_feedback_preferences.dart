import 'package:shared_preferences/shared_preferences.dart';

/// テスト時に実際の`SharedPreferences`を介さずに差し替えられるようにする
/// ための最小インターフェース（`DailyReminderPreferencesLike`と同じ役割）。
abstract class SoundFeedbackPreferencesLike {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool value);
}

/// 着手時の触覚・聴覚フィードバック（`reversia_move_feedback.dart`）の
/// オン/オフ設定の永続化 - `DailyReminderPreferences`/
/// `BoardThemePreferences`と同じく`SharedPreferences`のみを使う端末
/// ローカルな設定。project-015の`customization_provider.dart`が持って
/// いた`enableSoundEffects`トグルの移植漏れ。
class SoundFeedbackPreferences implements SoundFeedbackPreferencesLike {
  static const _enabledKey = 'reversia_feedback_enabled';

  @override
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  @override
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
