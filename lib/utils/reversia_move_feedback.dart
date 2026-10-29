import 'package:flutter/services.dart';

/// 着手時の触覚・聴覚フィードバック。GoEnの`stone_feedback.dart`と同じ
/// 設計判断 - 新規パッケージ/音声アセットを追加せず、Flutter標準の
/// HapticFeedback / SystemSoundだけで「着手した感」を出す（このサンド
/// ボックスには新規依存関係のpub取得・アセット同梱を検証できる
/// dart/flutterツーリングが無いため）。

/// フィードバックの有効/無効 - `SettingsScreen`のトグルから直接書き換え
/// られる、アプリ全体で共有される可変フラグ。呼び出し元が
/// `main.dart`/`reversia_pvp_game_screen.dart`の両方に分散しているため、
/// 各呼び出し元へパラメータとして配るより単純なこの方式にした
/// （`SoundFeedbackPreferences`が起動時にここへ反映する）。
bool reversiaFeedbackEnabled = true;

/// 普通の着手（相手の駒を取らない）。
void playReversiaMovePlaceFeedback() {
  if (!reversiaFeedbackEnabled) return;
  HapticFeedback.mediumImpact();
  SystemSound.play(SystemSoundType.click);
}

/// 着手が拒否された（PvP対局で相手の着手と競合した等）ときの軽い
/// フィードバック。
void playReversiaIllegalMoveFeedback() {
  if (!reversiaFeedbackEnabled) return;
  HapticFeedback.vibrate();
}

/// 相手の駒を自分の側に変える、または相手キングを捕獲して対局終了
/// させる着手 - 通常の着手より強めのフィードバック。
void playReversiaCaptureFeedback() {
  if (!reversiaFeedbackEnabled) return;
  HapticFeedback.heavyImpact();
  SystemSound.play(SystemSoundType.click);
}
