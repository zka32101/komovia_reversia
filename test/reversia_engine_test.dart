import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:test/test.dart';

void main() {
  final game = ReversiaGame();
  final engine = ReversiaEngine();

  group('ReversiaEngine', () {
    test('modelVersion is a non-empty identifier', () {
      expect(engine.modelVersion, isNotEmpty);
    });

    test('bestMove at the easy level returns a legal move from the start', () async {
      final pos = game.initialPosition();
      final move = await engine.bestMove(pos, level: 1);
      expect(move, isNotNull);
      expect(game.legalMoves(pos), contains(move));
    });

    test('bestMove at the hard level returns a legal move from the start', () async {
      final pos = game.initialPosition();
      final move = await engine.bestMove(pos, level: 3);
      expect(move, isNotNull);
      expect(game.legalMoves(pos), contains(move));
    });

    test('bestMove ignores an unsupported timeBudget and still returns a legal move', () async {
      final pos = game.initialPosition();
      final move = await engine.bestMove(
        pos,
        level: 3,
        timeBudget: const Duration(milliseconds: 50),
      );
      expect(move, isNotNull);
      expect(game.legalMoves(pos), contains(move));
    });

    test('evaluate the initial position is exactly balanced', () async {
      // The initial position mirrors exactly between the two sides
      // (material, strategic square weights, and mobility all match), so
      // unlike a heuristic-only estimate, this is an exact expectation.
      final pos = game.initialPosition();
      final score = await engine.evaluate(pos);
      expect(score, 0);
    });

    test('findForcedWin finds a 1-ply king capture when one exists', () async {
      final pos = ReversiaPosition(
        cells: [
          for (var i = 0; i < 36; i++)
            switch (i) {
              0 => const ReversiaPiece(
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front),
              1 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front),
              2 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front),
              _ => null,
            },
        ],
        sideToMove: Side.first,
      );
      expect(game.result(pos).isOngoing, isTrue);

      final move = await engine.findForcedWin(pos, maxPly: 1);
      expect(move, isNotNull);
      expect(game.legalMoves(pos), contains(move));

      final after = game.apply(pos, move!);
      final result = game.result(after);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.checkmate);
    });

    test('findForcedWin returns null when no forced win exists within maxPly', () async {
      final pos = game.initialPosition();
      final move = await engine.findForcedWin(pos, maxPly: 1);
      expect(move, isNull);
    });
  });
}
