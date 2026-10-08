import 'package:komovia_core/komovia_core.dart';

import 'reversia_game.dart';
import 'reversia_position.dart';

/// Strategic board/move evaluation for [ReversiaEngine], fixed to one
/// side's perspective (positive favors that side). Ported from
/// project-015's `lib/engine/ai_evaluator.dart` (`AdvancedEvaluator`/
/// `AiStrategy`), operating on [ReversiaPosition] via the public
/// `ReversiaGame` API instead of the original `Board`/`MoveGenerator`.
class ReversiaEvaluator {
  static const int kingValue = 500;
  static const int normalPieceValue = 100;
  static const int mobilityWeight = 15;
  static const int centerControlWeight = 20;
  static const int kingSafetyWeight = 80;
  static const int captureWeight = 150;

  static const int cornerWeight = 150;
  static const int edgeWeight = 50;
  static const int xSquareWeight = -30;
  static const int cSquareWeight = -20;

  final ReversiaGame _game;

  const ReversiaEvaluator(this._game);

  /// Comprehensive position evaluation from [side]'s perspective.
  int evaluate(ReversiaPosition position, Side side) {
    final myMoves = _game.legalMoves(position);
    final oppMoves = _legalMovesFor(position, side.opponent);

    var score = 0;
    score += _evaluateMaterial(position, side);
    score += _evaluateKingSafety(position, side, oppMoves);
    score += _evaluatePositionControl(position, side);
    score += _evaluateStrategicPosition(position, side);
    score += _evaluateMobility(myMoves, oppMoves);
    return score;
  }

  /// `Game.legalMoves` is defined for `position.sideToMove` only; this
  /// evaluator also needs the *opponent's* mobility/threats, so it builds
  /// a copy of [position] with [side] to move and asks the same way.
  /// Repetition/ply-limit never affect this (history-free `result()`
  /// only checks kings and mobility), so this is safe purely for
  /// evaluation purposes -- never for real turn-taking.
  List<Move> _legalMovesFor(ReversiaPosition position, Side side) {
    if (position.sideToMove == side) return _game.legalMoves(position);
    return _game.legalMoves(position.copyWith(sideToMove: side));
  }

  int _evaluateMaterial(ReversiaPosition position, Side side) {
    var mine = 0;
    var theirs = 0;
    for (final p in position.cells) {
      if (p == null) continue;
      final value = p.type == ReversiaPieceType.king ? kingValue : normalPieceValue;
      if (p.owner == side) {
        mine += value;
      } else {
        theirs += value;
      }
    }
    return mine - theirs;
  }

  int _evaluateKingSafety(
    ReversiaPosition position,
    Side side,
    List<Move> opponentMoves,
  ) {
    var kingThreatCount = 0;
    for (final move in opponentMoves) {
      if (move is! BoardMove) continue;
      final target = position.at(move.to);
      if (target != null && target.type == ReversiaPieceType.king && target.owner == side) {
        kingThreatCount++;
      }
    }
    return -kingThreatCount * kingSafetyWeight;
  }

  int _evaluatePositionControl(ReversiaPosition position, Side side) {
    const centerSquares = [Square(2, 2), Square(3, 2), Square(2, 3), Square(3, 3)];

    var mine = 0;
    var theirs = 0;
    for (final square in centerSquares) {
      final piece = position.at(square);
      if (piece == null) continue;
      if (piece.owner == side) {
        mine++;
      } else {
        theirs++;
      }
    }
    return (mine - theirs) * centerControlWeight;
  }

  int _evaluateStrategicPosition(ReversiaPosition position, Side side) {
    var score = 0;
    for (var file = 0; file < ReversiaPosition.boardSize; file++) {
      for (var rank = 0; rank < ReversiaPosition.boardSize; rank++) {
        final piece = position.at(Square(file, rank));
        if (piece == null || piece.owner != side) continue;
        score += _squareWeight(file, rank);
      }
    }
    return score;
  }

  /// Classifies one square's strategic importance (corners are safe and
  /// permanent, X-squares diagonally adjacent to a corner are risky, ...).
  /// Symmetric in file/rank, so which axis is "row" vs. "column" doesn't
  /// matter -- ported from `AdvancedEvaluator._classifySquare`.
  static int _squareWeight(int file, int rank) {
    final edge = ReversiaPosition.boardSize - 1;
    final onFileEdge = file == 0 || file == edge;
    final onRankEdge = rank == 0 || rank == edge;

    if (onFileEdge && onRankEdge) return cornerWeight; // corner
    if ((rank == 1 || rank == edge - 1) && (file == 1 || file == edge - 1)) {
      return xSquareWeight; // diagonally adjacent to a corner
    }
    if (onRankEdge && (file == 1 || file == edge - 1)) return cSquareWeight;
    if (onFileEdge && (rank == 1 || rank == edge - 1)) return cSquareWeight;
    if (onFileEdge || onRankEdge) return edgeWeight;
    return 0; // interior
  }

  int _evaluateMobility(List<Move> myMoves, List<Move> oppMoves) =>
      (myMoves.length - oppMoves.length) * mobilityWeight;

  /// Evaluates one candidate [move] for greedy (non-search) move selection.
  int evaluateMove(ReversiaPosition position, Move move, Side side) {
    if (move is! BoardMove) return 0;

    var score = 0;
    final target = position.at(move.to);
    if (target != null && target.type == ReversiaPieceType.king && target.owner != side) {
      score += 10000;
    } else if (target != null && target.owner != side) {
      score += captureWeight;
    }

    const center = (ReversiaPosition.boardSize - 1) / 2;
    final distFromCenter = (move.to.file - center).abs() + (move.to.rank - center).abs();
    score += (ReversiaPosition.boardSize - distFromCenter.toInt()) * 5;

    return score;
  }

  /// Easy-tier move scoring: captures are slightly preferred, otherwise
  /// indifferent (the bulk of "easy" randomness lives in
  /// `ReversiaEngine._pickEasy`, not here).
  int evaluateMoveEasy(ReversiaPosition position, Move move, Side side) {
    if (move is! BoardMove) return 0;
    final target = position.at(move.to);
    return (target != null && target.owner != side) ? 50 : 0;
  }
}
