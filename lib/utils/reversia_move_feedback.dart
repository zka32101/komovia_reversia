import 'package:flutter/services.dart';

/// 着手時の触覚・聴覚フィードバック。GoEnの`stone_feedback.dart`と同じ
/// 設計判断 - 新規パッケージ/音声アセットを追加せず、Flutter標準の
/// HapticFeedback / SystemSoundだけで「着手した感」を出す（このサンド
/// ボックスには新規依存関係のpub取得・アセット同梱を検証できる
/// dart/flutterツーリングが無いため）。

/// 普通の着手（相手の駒を取らない）。
void playReversiaMovePlaceFeedback() {
  HapticFeedback.mediumImpact();
  SystemSound.play(SystemSoundType.click);
}

/// 着手が拒否された（PvP対局で相手の着手と競合した等）ときの軽い
/// フィードバック。
void playReversiaIllegalMoveFeedback() {
  HapticFeedback.vibrate();
}

/// 相手の駒を自分の側に変える、または相手キングを捕獲して対局終了
/// させる着手 - 通常の着手より強めのフィードバック。
void playReversiaCaptureFeedback() {
  HapticFeedback.heavyImpact();
  SystemSound.play(SystemSoundType.click);
}
