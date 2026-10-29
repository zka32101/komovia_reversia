import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

void main() {
  group('ReversiaGameAnalyzer', () {
    final game = ReversiaGame();

    test('an empty move list produces no reviews and a neutral summary', () {
      final analysis = ReversiaGameAnalyzer(game: game).analyze(
        initialPosition: game.initialPosition(),
        moves: const [],
        side: Side.first,
      );

      expect(analysis.moveReviews, isEmpty);
      expect(analysis.mistakeCount, 0);
      expect(analysis.summary, isNotEmpty);
    });

    test(
        'always picking the evaluator\'s own best move at every turn scores '
        'no loss', () {
      final evaluator = ReversiaEvaluator(game);
      var position = game.initialPosition();
      final historyKeys = <Object>[game.positionKey(position)];
      final moves = <RecordedMove>[];

      // 数手だけ、両者ともその局面でのReversiaEvaluator基準の最善手を
      // 選び続ける - 解析対象(Side.first)についてはlossVsBestが常に0に
      // なるはず（解析自体も同じevaluatorを使うため）。
      for (var i = 0; i < 4; i++) {
        final side = position.sideToMove;
        final legal = game.legalMoves(position, historyKeys: historyKeys);
        if (legal.isEmpty) break;

        Move? best;
        var bestEval = -(1 << 30);
        for (final candidate in legal) {
          final resulting =
              game.apply(position, candidate, historyKeys: historyKeys);
          final eval = evaluator.evaluate(resulting, side);
          if (eval > bestEval) {
            bestEval = eval;
            best = candidate;
          }
        }

        moves.add(RecordedMove(number: i + 1, side: side, move: best!));
        position = game.apply(position, best, historyKeys: historyKeys);
        historyKeys.add(game.positionKey(position));
      }

      final analysis = ReversiaGameAnalyzer(game: game).analyze(
        initialPosition: game.initialPosition(),
        moves: moves,
        side: Side.first,
      );

      for (final review in analysis.moveReviews) {
        expect(review.lossVsBest, 0);
        expect(review.quality, ReversiaMoveQuality.excellent);
        expect(review.bestAlternativeMove, isNull,
            reason: 'already-best moves have nothing better to suggest');
      }
    });

    test('a deliberately bad move is flagged with a nonzero loss', () {
      var position = game.initialPosition();
      final historyKeys = <Object>[game.positionKey(position)];
      final legal = game.legalMoves(position, historyKeys: historyKeys);
      expect(legal.length, greaterThan(1),
          reason: 'need at least 2 options to have a worst move');

      final evaluator = ReversiaEvaluator(game);
      // 最善手と最悪手の両方を特定する。
      Move? best;
      Move? worst;
      var bestEval = -(1 << 30);
      var worstEval = 1 << 30;
      for (final move in legal) {
        final resulting = game.apply(position, move, historyKeys: historyKeys);
        final eval = evaluator.evaluate(resulting, Side.first);
        if (eval > bestEval) {
          bestEval = eval;
          best = move;
        }
        if (eval < worstEval) {
          worstEval = eval;
          worst = move;
        }
      }
      // 最善手と最悪手が同一（全手が同評価）ならテストの前提が崩れる。
      if (best == worst) return;

      final analysis = ReversiaGameAnalyzer(game: game).analyze(
        initialPosition: position,
        moves: [RecordedMove(number: 1, side: Side.first, move: worst!)],
        side: Side.first,
      );

      expect(analysis.moveReviews.single.lossVsBest, greaterThan(0));
      expect(analysis.moveReviews.single.bestAlternativeMove, best);
    });

    test('bestLegalMove returns null when the side has no legal moves', () {
      // A position with no pieces for Side.first has no legal moves for it.
      final empty = game.initialPosition().copyWith(
            cells: List.filled(ReversiaPosition.boardSize * ReversiaPosition.boardSize, null),
            sideToMove: Side.first,
          );
      final best =
          bestLegalMove(game, ReversiaEvaluator(game), empty, Side.first);
      expect(best, isNull);
    });

    test('bestLegalMove picks the evaluator-highest-scoring legal move', () {
      final position = game.initialPosition();
      final historyKeys = <Object>[game.positionKey(position)];
      final evaluator = ReversiaEvaluator(game);

      final best =
          bestLegalMove(game, evaluator, position, Side.first, historyKeys: historyKeys);
      expect(best, isNotNull);

      final legal = game
          .legalMoves(position, historyKeys: historyKeys)
          .whereType<BoardMove>();
      final bestEval = evaluator.evaluate(
        game.apply(position, best!, historyKeys: historyKeys),
        Side.first,
      );
      for (final candidate in legal) {
        final eval = evaluator.evaluate(
          game.apply(position, candidate, historyKeys: historyKeys),
          Side.first,
        );
        expect(bestEval, greaterThanOrEqualTo(eval));
      }
    });

    test('moves by the other side are replayed but not reviewed', () {
      var position = game.initialPosition();
      final historyKeys = <Object>[game.positionKey(position)];
      final legal = game.legalMoves(position, historyKeys: historyKeys);
      final move = legal.first;
      position = game.apply(position, move, historyKeys: historyKeys);
      final legal2 = game.legalMoves(position, historyKeys: historyKeys);

      final analysis = ReversiaGameAnalyzer(game: game).analyze(
        initialPosition: game.initialPosition(),
        moves: [
          RecordedMove(number: 1, side: Side.first, move: move),
          RecordedMove(number: 2, side: Side.second, move: legal2.first),
        ],
        side: Side.first,
      );

      expect(analysis.moveReviews, hasLength(1));
      expect(analysis.moveReviews.single.side, Side.first);
    });
  });
}
