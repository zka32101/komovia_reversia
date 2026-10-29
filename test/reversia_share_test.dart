import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

void main() {
  group('buildReversiaResultShareText', () {
    test('a win for the human side', () {
      final text = buildReversiaResultShareText(
        const GameResult.win(Side.first, WinReason.checkmate),
        humanSide: Side.first,
        moveCount: 12,
      );

      expect(text, contains('勝ちました！'));
      expect(text, contains('手数: 12手'));
      expect(text, contains('Komovia Reversia'));
      expect(text, contains('#KomoviaReversia'));
    });

    test('a loss for the human side', () {
      final text = buildReversiaResultShareText(
        const GameResult.win(Side.second, WinReason.checkmate),
        humanSide: Side.first,
        moveCount: 7,
      );

      expect(text, contains('惜しくも敗戦…'));
      expect(text, contains('手数: 7手'));
    });

    test('a draw', () {
      final text = buildReversiaResultShareText(
        const GameResult.draw(WinReason.score),
        humanSide: Side.first,
        moveCount: 100,
      );

      expect(text, contains('引き分けでした！'));
      expect(text, contains('手数: 100手'));
    });

    test('a win for the opposing human side (PvP perspective)', () {
      final text = buildReversiaResultShareText(
        const GameResult.win(Side.second, WinReason.checkmate),
        humanSide: Side.second,
        moveCount: 5,
      );

      expect(text, contains('勝ちました！'));
    });
  });
}
