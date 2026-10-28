import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

void main() {
  final game = ReversiaGame();

  test('二枚落ち removes only 後手\'s back-row corner pieces', () {
    final standard = game.initialPosition();
    final handicapped = ReversiaHandicapRule.two.apply(standard);

    expect(handicapped.at(const Square(0, 5)), isNull);
    expect(handicapped.at(const Square(5, 5)), isNull);
    // Everything else is untouched.
    for (var file = 0; file < ReversiaPosition.boardSize; file++) {
      for (var rank = 0; rank < ReversiaPosition.boardSize; rank++) {
        final square = Square(file, rank);
        if (square == const Square(0, 5) || square == const Square(5, 5)) {
          continue;
        }
        expect(handicapped.at(square), standard.at(square));
      }
    }
  });

  test('四枚落ち removes four of 後手\'s back-row pieces', () {
    final standard = game.initialPosition();
    final handicapped = ReversiaHandicapRule.four.apply(standard);

    for (final col in ReversiaHandicapRule.four.removedCols) {
      expect(handicapped.at(Square(col, 5)), isNull);
    }
  });

  test('六枚落ち removes 後手\'s entire back row but keeps its king', () {
    final standard = game.initialPosition();
    final handicapped = ReversiaHandicapRule.six.apply(standard);

    for (var col = 0; col < ReversiaPosition.boardSize; col++) {
      expect(handicapped.at(Square(col, 5)), isNull);
    }
    expect(handicapped.hasKing(Side.second), isTrue);
    // Side.first still moves first, same as a standard game.
    expect(handicapped.sideToMove, Side.first);
  });

  test('handicap does not mutate the standard initial position', () {
    final standard = game.initialPosition();
    ReversiaHandicapRule.six.apply(standard);
    expect(standard.at(const Square(0, 5)), isNotNull);
  });

  test('a handicapped position is still playable via legalMoves/apply', () {
    final handicapped = ReversiaHandicapRule.two.apply(game.initialPosition());
    final moves = game.legalMoves(handicapped);
    expect(moves, isNotEmpty);
    final after = game.apply(handicapped, moves.first);
    expect(after.sideToMove, Side.second);
  });
}
