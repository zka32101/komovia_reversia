import 'package:shared_preferences/shared_preferences.dart';

import '../src/reversia_board_theme.dart';

/// テスト時に実際の`SharedPreferences`を介さずに差し替えられるようにする
/// ための最小インターフェース（`DailyReminderPreferencesLike`と同じ役割）。
abstract class BoardThemePreferencesLike {
  Future<ReversiaBoardTheme> getTheme();
  Future<void> setTheme(ReversiaBoardTheme theme);
}

/// 盤・駒の配色テーマの永続化 - `DailyReminderPreferences`と同じく
/// `SharedPreferences`のみを使う端末ローカルな設定。
class BoardThemePreferences implements BoardThemePreferencesLike {
  static const _themeIdKey = 'reversia_board_theme_id';

  @override
  Future<ReversiaBoardTheme> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return ReversiaBoardTheme.byId(prefs.getString(_themeIdKey));
  }

  @override
  Future<void> setTheme(ReversiaBoardTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeIdKey, theme.id);
  }
}
