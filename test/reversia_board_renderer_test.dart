import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

void main() {
  final game = ReversiaGame();
  final renderer = ReversiaBoardRenderer();

  group('ReversiaBoardRenderer.build', () {
    testWidgets('builds the initial position without throwing', (tester) async {
      final pos = game.initialPosition();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: renderer.build(pos),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds with a last move, hints, and a selected square',
        (tester) async {
      final pos = game.initialPosition();
      final move = game.legalMoves(pos).first;
      final after = game.apply(pos, move);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: renderer.build(
                  after,
                  lastMove: move,
                  hints: const [Square(2, 2)],
                  selected: const Square(0, 0),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ReversiaBoardRenderer.squareAt', () {
    test('maps an offset inside the board to the right square', () {
      final pos = game.initialPosition();
      const boardSize = BoardSize(360, 360); // cellSize = 360 / 6 = 60
      final topLeft = renderer.squareAt(const BoardOffset(10, 10), boardSize, pos);
      expect(topLeft, const Square(0, 0));

      final bottomRight = renderer.squareAt(const BoardOffset(355, 355), boardSize, pos);
      expect(bottomRight, const Square(5, 5));
    });

    test('returns null outside the board', () {
      final pos = game.initialPosition();
      const boardSize = BoardSize(360, 360);
      expect(renderer.squareAt(const BoardOffset(-5, 10), boardSize, pos), isNull);
      expect(renderer.squareAt(const BoardOffset(1000, 10), boardSize, pos), isNull);
    });
  });
}
