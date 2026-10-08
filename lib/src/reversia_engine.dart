import 'dart:math';

import 'package:komovia_core/komovia_core.dart';

import 'reversia_evaluator.dart';
import 'reversia_game.dart';
import 'reversia_position.dart';

/// Reversia's `Engine<ReversiaPosition>`. Ported from project-015's
/// `lib/engine/ai.dart` (`ReversiaAi`), which covered three difficulty
/// tiers:
/// - easy ([level] 1): mostly a uniform random legal move.
/// - medium ([level] 2): greedy 1-ply, preferring a king capture, then
///   the most material/strategic gain, then random.
/// - hard ([level] 3+): minimax with alpha-beta pruning, deeper once few
///   pieces remain (project-015's "endgame" search-depth bump).
///
/// [timeBudget] is accepted (per `Engine.bestMove`'s contract) but
/// ignored: unlike komovia_shogi's `AI.bestMoveTimed`, project-015's AI
/// has no iterative-deepening search to budget -- it's a fixed-depth
/// search at every level. Runs synchronously in the caller's isolate;
/// project-015's board is tiny enough (6x6, <=18 pieces, depth <=8) that
/// this hasn't needed `Isolate.run`/`compute()` the way komovia_shogi's
/// deeper shogi search does.
class ReversiaEngine implements Engine<ReversiaPosition> {
  static const int _hardSearchDepth = 4;
  static const int _endgameSearchDepth = 8;

  /// See project-015's `ReversiaAi._endgamePieceThreshold`: Reversia
  /// starts with 18 pieces and pieces are only ever removed (a king
  /// capture) or converted in place, never added, so this must stay well
  /// below 18 or every game would spend its whole duration in "endgame"
  /// mode.
  static const int _endgamePieceThreshold = 10;

  static const int _infinity = 1 << 20;

  final ReversiaGame _game;
  final ReversiaEvaluator _evaluator;
  final Random _random;

  factory ReversiaEngine({ReversiaGame? game, Random? random}) {
    final resolvedGame = game ?? ReversiaGame();
    return ReversiaEngine._(
      resolvedGame,
      ReversiaEvaluator(resolvedGame),
      random ?? Random(),
    );
  }

  ReversiaEngine._(this._game, this._evaluator, this._random);

  @override
  String get modelVersion => 'builtin';

  @override
  Future<Move?> bestMove(
    ReversiaPosition position, {
    required int level,
    Duration? timeBudget,
  }) async {
    final moves = _game.legalMoves(position);
    if (moves.isEmpty) return null;

    if (level <= 1) return _pickEasy(position, moves);
    if (level == 2) return _pickGreedy(position, moves);
    return _pickMinimax(position, moves);
  }

  @override
  Future<double> evaluate(ReversiaPosition position) async =>
      _evaluator.evaluate(position, Side.first).toDouble();

  @override
  Future<Move?> findForcedWin(
    ReversiaPosition position, {
    required int maxPly,
  }) async {
    final moves = _game.legalMoves(position);
    if (moves.isEmpty) return null;

    Move? best;
    var bestScore = -_infinity;
    for (final move in moves) {
      final child = _game.apply(position, move);
      final score = -_negamax(child, maxPly - 1, -_infinity, _infinity);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    // Only report a move when it's a *proven* forced win within maxPly,
    // not merely the least-bad option -- mirrors Engine.findForcedWin's
    // "null if no forced win within maxPly is found" contract.
    return bestScore >= _infinity ? best : null;
  }

  Move _pickEasy(ReversiaPosition position, List<Move> moves) {
    if (_random.nextDouble() < 0.8) {
      return moves[_random.nextInt(moves.length)];
    }

    Move? best;
    var bestScore = -100;
    for (final move in moves) {
      final score = _evaluator.evaluateMoveEasy(position, move, position.sideToMove);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best ?? moves[_random.nextInt(moves.length)];
  }

  Move _pickGreedy(ReversiaPosition position, List<Move> moves) {
    Move? best;
    var bestScore = -9999;
    for (final move in moves) {
      final score = _evaluator.evaluateMove(position, move, position.sideToMove);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best ?? moves[_random.nextInt(moves.length)];
  }

  Move _pickMinimax(ReversiaPosition position, List<Move> moves) {
    final depth = _searchDepth(position);

    Move? best;
    var bestScore = -_infinity;
    for (final move in moves) {
      final child = _game.apply(position, move);
      final score = -_negamax(child, depth - 1, -_infinity, _infinity);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best ?? moves[_random.nextInt(moves.length)];
  }

  int _searchDepth(ReversiaPosition position) {
    final totalPieces =
        position.pieceCount(Side.first) + position.pieceCount(Side.second);
    return totalPieces <= _endgamePieceThreshold ? _endgameSearchDepth : _hardSearchDepth;
  }

  /// Negamax from `position.sideToMove`'s perspective. Ignores
  /// repetition/ply-limit entirely (search has no real game history to
  /// check those against) and only cares about king capture, mirroring
  /// project-015's `ReversiaAi._negamax` exactly.
  int _negamax(ReversiaPosition position, int depth, int alpha, int beta) {
    final side = position.sideToMove;
    if (!position.hasKing(side)) return -_infinity;
    if (!position.hasKing(side.opponent)) return _infinity;
    if (depth == 0) return _evaluator.evaluate(position, side);

    final moves = _game.legalMoves(position);
    if (moves.isEmpty) return -_infinity; // no legal moves -> loss

    var value = -_infinity;
    for (final move in moves) {
      final child = _game.apply(position, move);
      final score = -_negamax(child, depth - 1, -beta, -alpha);
      if (score > value) value = score;
      if (value > alpha) alpha = value;
      if (alpha >= beta) break;
    }
    return value;
  }
}
