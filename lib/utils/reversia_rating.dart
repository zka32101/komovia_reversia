import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_core/komovia_core.dart' show GameResult, ResultKind, Side;

/// AI対局のレーティング計算。math自体はkomovia_core（`computeEloDelta`/
/// `ratingForAiLevel`）に集約済みで、ここは「`ReversiaEngine.bestMove`の
/// `level`(1-3)をどの仮想レーティングに対応させるか」という、このアプリ
/// 固有のマッピングだけを持つ薄いラッパー（komovia_shogiの
/// `lib/utils/shogi_rating.dart`と同じ役割分担）。
///
/// `ReversiaEngine`自体はまだ難易度選択UIを持たない（`main.dart`は
/// `level: 2`固定）が、レーティング計算は任意のlevelに対応しておき、
/// 難易度選択UIが後から追加されてもここは変更不要にする。

/// 難易度レベルに応じた仮想レーティング。level2(標準)を基準(1200)とし、
/// 1段階ごとに±200。level1=1000 / level2=1200 / level3=1400。
int opponentRatingForLevel(int level) {
  return core.ratingForAiLevel(
    level: level,
    minLevel: 1,
    maxLevel: 3,
    baseLevel: 2,
    step: 200,
  );
}

/// [result]が未確定(`ResultKind.ongoing`)の場合は`0`を返す。
int computeReversiaRatingDelta({
  required int currentRating,
  required int aiLevel,
  required GameResult result,
  required Side humanSide,
}) {
  if (result.kind == ResultKind.ongoing) return 0;
  final double score;
  if (result.kind == ResultKind.draw) {
    score = 0.5;
  } else if (result.winner == humanSide) {
    score = 1.0;
  } else {
    score = 0.0;
  }
  return core.computeEloDelta(
    currentRating: currentRating,
    opponentRating: opponentRatingForLevel(aiLevel),
    score: score,
  );
}
