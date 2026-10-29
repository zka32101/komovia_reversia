import 'package:shared_preferences/shared_preferences.dart';

/// `ReversiaGameScreen`がテスト時に実際の`SharedPreferences`を介さずに
/// 差し替えられるようにするための最小インターフェース。
abstract class GameSaveServiceLike {
  Future<String?> loadInProgressGame();
  Future<void> saveInProgressGame(String movesRecord);
  Future<void> clearInProgressGame();
}

/// AI対局（ホーム画面から「プレイ」で始まる1局）の進行状況を、
/// `ReversiaGame.exportRecord`が返す着手レコード文字列としてそのまま
/// 端末ローカルに保存する - `DailyReminderPreferences`と同じく
/// `SharedPreferences`のみを使う端末ローカルな状態（アカウントデータ
/// ではない）。局面自体は保存せず、初期局面から着手を再生して復元する
/// （`ReversiaPvpGameService._replay`と同じ方式）。
class GameSaveService implements GameSaveServiceLike {
  static const _key = 'reversia_in_progress_game';

  @override
  Future<String?> loadInProgressGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> saveInProgressGame(String movesRecord) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, movesRecord);
  }

  @override
  Future<void> clearInProgressGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
