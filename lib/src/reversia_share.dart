import 'package:komovia_core/komovia_core.dart';

/// 対局結果のSNS共有キャプションを組み立てる純粋関数 - `main.dart`の
/// `_shareResult`から切り出し、`SharePlus`のプラットフォームチャンネル
/// を介さずにロジック単体でテストできるようにしている。
///
/// komovia_coreの`ShareableMoment`/`buildShareCaption`を使い、他の
/// Komoviaシリーズ（shogi/go/chess）の結果シェアと同じキャプション
/// 形式に揃える（project-015には同等機能が無かった - 競合Othello/
/// Reversiアプリの多くが持つ結果シェア機能の移植漏れ）。
String buildReversiaResultShareText(
  GameResult result, {
  required Side humanSide,
  required int moveCount,
}) {
  final isDraw = result.kind == ResultKind.draw;
  final won = result.winner == humanSide;
  final headline = switch ((won, isDraw)) {
    (_, true) => '引き分けでした！',
    (true, false) => '勝ちました！',
    (false, false) => '惜しくも敗戦…',
  };

  return buildShareCaption(
    ShareableMoment(
      appName: 'Komovia Reversia',
      headline: headline,
      statLines: ['手数: $moveCount手'],
      hashtag: '#KomoviaReversia',
    ),
  );
}
