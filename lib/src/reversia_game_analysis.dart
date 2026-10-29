import 'package:komovia_core/komovia_core.dart';

import 'reversia_evaluator.dart';
import 'reversia_game.dart';
import 'reversia_position.dart';

/// How much a played move's resulting evaluation trails the best legal
/// alternative available at the time, in [ReversiaEvaluator] points.
/// Thresholds mirror the familiar centipawn-loss tiers chess analysis
/// tools use, scaled to this evaluator's own weights (a single captured
/// normal piece is [ReversiaEvaluator.captureWeight] = 150 points, so
/// [mistake]/[blunder] roughly track "missed a free piece" /
/// "handed over a piece or worse").
enum ReversiaMoveQuality {
  excellent,
  good,
  inaccuracy,
  mistake,
  blunder;

  static ReversiaMoveQuality fromLoss(int loss) {
    if (loss <= 20) return ReversiaMoveQuality.excellent;
    if (loss <= 60) return ReversiaMoveQuality.good;
    if (loss <= 150) return ReversiaMoveQuality.inaccuracy;
    if (loss <= 400) return ReversiaMoveQuality.mistake;
    return ReversiaMoveQuality.blunder;
  }

  /// 日本語の対局後レビュー表示向けラベル。
  String get label {
    switch (this) {
      case ReversiaMoveQuality.excellent:
        return '最善手';
      case ReversiaMoveQuality.good:
        return '良い手';
      case ReversiaMoveQuality.inaccuracy:
        return 'やや不正確';
      case ReversiaMoveQuality.mistake:
        return '悪手';
      case ReversiaMoveQuality.blunder:
        return '大悪手';
    }
  }
}

/// One played move's review: how it compares to the best legal
/// alternative available at that position, evaluated from the mover's
/// own perspective both times so the comparison is apples-to-apples
/// regardless of whose turn came next.
class ReversiaMoveReview {
  final int moveNumber;
  final Side side;
  final Move move;
  final int evalBefore;
  final int evalAfterMove;
  final int evalAfterBestAlternative;

  const ReversiaMoveReview({
    required this.moveNumber,
    required this.side,
    required this.move,
    required this.evalBefore,
    required this.evalAfterMove,
    required this.evalAfterBestAlternative,
  });

  /// How many evaluation points worse the played move was than the best
  /// alternative. Always `>= 0` by construction (the played move's
  /// outcome can never exceed the best one found among all legal moves,
  /// itself included).
  int get lossVsBest => evalAfterBestAlternative - evalAfterMove;

  ReversiaMoveQuality get quality => ReversiaMoveQuality.fromLoss(lossVsBest);
}

/// The full review of one side's moves across a finished (or in-progress)
/// game: each move's [ReversiaMoveReview] plus a plain-language summary,
/// the local analogue of the "敗因分析" (why-you-lost critique) and
/// "棋譜解析" (move-record analysis) features competitor Othello-like
/// apps advertise as a core improvement loop. Deterministic and fully
/// local (built on [ReversiaEvaluator], not an LLM) — this app has no
/// AI-commentary backend of its own.
class ReversiaGameAnalysis {
  final Side analyzedSide;
  final List<ReversiaMoveReview> moveReviews;

  const ReversiaGameAnalysis({
    required this.analyzedSide,
    required this.moveReviews,
  });

  int get mistakeCount => moveReviews
      .where((r) =>
          r.quality == ReversiaMoveQuality.mistake ||
          r.quality == ReversiaMoveQuality.blunder)
      .length;

  int get blunderCount =>
      moveReviews.where((r) => r.quality == ReversiaMoveQuality.blunder).length;

  /// The single worst move by [ReversiaMoveReview.lossVsBest], or `null`
  /// if no moves were played.
  ReversiaMoveReview? get worstMove {
    if (moveReviews.isEmpty) return null;
    return moveReviews.reduce((a, b) => b.lossVsBest > a.lossVsBest ? b : a);
  }

  /// One-paragraph plain-language conclusion, e.g. for a post-game review
  /// screen's headline.
  String get summary {
    if (moveReviews.isEmpty) return '着手の記録がありませんでした。';
    final worst = worstMove!;
    if (blunderCount == 0 && mistakeCount == 0) {
      return '安定した対局でした。目立った悪手はありませんでした。';
    }
    final kind = worst.quality == ReversiaMoveQuality.blunder ? '大悪手' : '悪手';
    return '最大のミスは${worst.moveNumber}手目の$kind（最善手との差${worst.lossVsBest}点）でした。'
        '合計で${mistakeCount}手の悪手がありました。';
  }
}

/// Finds the legal move (among [BoardMove]s only) that [evaluator] scores
/// highest from [side]'s own perspective after it's applied, at
/// [position]. Returns `null` if [side] has no legal moves. Shared by
/// [ReversiaGameAnalyzer] (to find each turn's best alternative) and the
/// app's own in-game hint feature (to suggest one move without playing
/// it) — both need the identical "best move by this evaluator" search.
BoardMove? bestLegalMove(
  ReversiaGame game,
  ReversiaEvaluator evaluator,
  ReversiaPosition position,
  Side side, {
  List<Object> historyKeys = const [],
}) {
  final legal = game
      .legalMoves(position, historyKeys: historyKeys)
      .whereType<BoardMove>();

  BoardMove? best;
  var bestEval = -(1 << 30);
  for (final candidate in legal) {
    final resulting = game.apply(position, candidate, historyKeys: historyKeys);
    final eval = evaluator.evaluate(resulting, side);
    if (eval > bestEval) {
      bestEval = eval;
      best = candidate;
    }
  }
  return best;
}

/// Builds a [ReversiaGameAnalysis] for one side by replaying every move
/// in [moves] and, at each of that side's turns, comparing the move
/// actually played against every other legal move available at that
/// position.
class ReversiaGameAnalyzer {
  ReversiaGameAnalyzer({ReversiaGame? game, ReversiaEvaluator? evaluator})
      : _game = game ?? ReversiaGame(),
        _evaluator = evaluator;

  final ReversiaGame _game;
  final ReversiaEvaluator? _evaluator;

  ReversiaEvaluator get _eval => _evaluator ?? ReversiaEvaluator(_game);

  ReversiaGameAnalysis analyze({
    required ReversiaPosition initialPosition,
    required List<RecordedMove> moves,
    required Side side,
  }) {
    var position = initialPosition;
    final historyKeys = <Object>[_game.positionKey(position)];
    final reviews = <ReversiaMoveReview>[];

    for (final recorded in moves) {
      if (recorded.side != side) {
        position = _game.apply(position, recorded.move, historyKeys: historyKeys);
        historyKeys.add(_game.positionKey(position));
        continue;
      }

      final evalBefore = _eval.evaluate(position, side);
      final legal = _game.legalMoves(position, historyKeys: historyKeys);

      // A validly-played game always has its recorded move among the
      // legal moves at that position; skip (rather than guess at) a
      // review for a move that somehow isn't, instead of crashing on the
      // `apply` below or reporting a misleading zero-loss review.
      if (legal.contains(recorded.move)) {
        var bestEval = -(1 << 30);
        var playedEval = bestEval;
        for (final candidate in legal) {
          final resultingPosition =
              _game.apply(position, candidate, historyKeys: historyKeys);
          final candidateEval = _eval.evaluate(resultingPosition, side);
          if (candidateEval > bestEval) bestEval = candidateEval;
          if (candidate == recorded.move) playedEval = candidateEval;
        }

        reviews.add(ReversiaMoveReview(
          moveNumber: recorded.number,
          side: side,
          move: recorded.move,
          evalBefore: evalBefore,
          evalAfterMove: playedEval,
          evalAfterBestAlternative: bestEval,
        ));
      }

      position = _game.apply(position, recorded.move, historyKeys: historyKeys);
      historyKeys.add(_game.positionKey(position));
    }

    return ReversiaGameAnalysis(analyzedSide: side, moveReviews: reviews);
  }
}
