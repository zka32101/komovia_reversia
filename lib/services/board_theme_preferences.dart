import 'package:shared_preferences/shared_preferences.dart';

import '../src/reversia_board_theme.dart';
import '../src/reversia_cosmetics.dart';

/// テスト時に実際の`SharedPreferences`を介さずに差し替えられるようにする
/// ための最小インターフェース（`DailyReminderPreferencesLike`と同じ役割）。
abstract class BoardThemePreferencesLike {
  /// 選択中の盤スキン・駒スキンから描画テーマを組み立てる。
  /// [hasActiveSubscription]がfalseなら、サポーター向けスキンは既定に
  /// 戻した見た目になる（選択自体は保存したまま - 再加入で元に戻る）。
  Future<ReversiaBoardTheme> getTheme({bool hasActiveSubscription = false});
  Future<void> setTheme(ReversiaBoardTheme theme);
  Future<String> getBoardSkinId();
  Future<String> getDiscSkinId();
  Future<void> setBoardSkinId(String id);
  Future<void> setDiscSkinId(String id);
}

/// 盤・駒の配色テーマ（コスメティックの盤スキン/駒スキン）の永続化 -
/// `DailyReminderPreferences`/`AvatarPreferences`と同じく
/// `SharedPreferences`のみを使う端末ローカルな設定。
///
/// 盤スキン・駒スキン導入前は`_themeIdKey`に既存テーマid（木目/墨/翡翠）
/// を1つだけ保存していた。新しいキーが未保存の場合はその値を盤・駒の
/// 両方に使うので、既存ユーザーの見た目は変わらない。
class BoardThemePreferences implements BoardThemePreferencesLike {
  static const _themeIdKey = 'reversia_board_theme_id';
  static const _boardSkinKey = 'reversia_board_skin_id';
  static const _discSkinKey = 'reversia_disc_skin_id';

  @override
  Future<String> getBoardSkinId() async {
    final prefs = await SharedPreferences.getInstance();
    return ReversiaCosmetics.boardSkinById(
      prefs.getString(_boardSkinKey) ?? prefs.getString(_themeIdKey),
    ).id;
  }

  @override
  Future<String> getDiscSkinId() async {
    final prefs = await SharedPreferences.getInstance();
    return ReversiaCosmetics.discSkinById(
      prefs.getString(_discSkinKey) ?? prefs.getString(_themeIdKey),
    ).id;
  }

  @override
  Future<void> setBoardSkinId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boardSkinKey, id);
  }

  @override
  Future<void> setDiscSkinId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_discSkinKey, id);
  }

  @override
  Future<ReversiaBoardTheme> getTheme({bool hasActiveSubscription = false}) async {
    return ReversiaCosmetics.resolveTheme(
      boardSkinId: await getBoardSkinId(),
      discSkinId: await getDiscSkinId(),
      hasActiveSubscription: hasActiveSubscription,
    );
  }

  /// 対局画面の簡易配色ダイアログ用（既存テーマ = 盤・駒が同じidの組）。
  @override
  Future<void> setTheme(ReversiaBoardTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeIdKey, theme.id);
    await prefs.setString(_boardSkinKey, theme.id);
    await prefs.setString(_discSkinKey, theme.id);
  }
}
