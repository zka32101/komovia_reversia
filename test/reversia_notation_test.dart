import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

void main() {
  group('reversiaSquareNotation', () {
    test('the bottom-left corner is a1', () {
      expect(reversiaSquareNotation(const Square(0, 0)), 'a1');
    });

    test('the top-right corner of a 6x6 board is f6', () {
      expect(reversiaSquareNotation(const Square(5, 5)), 'f6');
    });

    test('a middle square', () {
      expect(reversiaSquareNotation(const Square(2, 3)), 'c4');
    });
  });

  group('reversiaMoveNotation', () {
    test('a board move is <from><to>', () {
      final move = const BoardMove(from: Square(2, 3), to: Square(3, 4));
      expect(reversiaMoveNotation(move), 'c4d5');
    });

    test('a resignation', () {
      expect(reversiaMoveNotation(const ResignMove(Side.first)), '投了');
    });
  });
}
