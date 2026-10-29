import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/utils/reversia_rating.dart';

void main() {
  group('opponentRatingForLevel', () {
    test('level 2 (the base level) maps to 1200 exactly', () {
      expect(opponentRatingForLevel(2), 1200);
    });

    test('each level step is 200 points apart', () {
      expect(opponentRatingForLevel(1), 1000);
      expect(opponentRatingForLevel(2), 1200);
      expect(opponentRatingForLevel(3), 1400);
    });

    test('an out-of-range level clamps to the nearest valid level', () {
      expect(opponentRatingForLevel(0), 1000);
      expect(opponentRatingForLevel(99), 1400);
    });
  });

  group('computeReversiaRatingDelta', () {
    test('an ongoing result never changes the rating', () {
      final delta = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 2,
        result: GameResult.ongoing,
        humanSide: Side.first,
      );
      expect(delta, 0);
    });

    test('beating the AI at an equal virtual rating gains points', () {
      final delta = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 2,
        result: const GameResult.win(Side.first, WinReason.score),
        humanSide: Side.first,
      );
      expect(delta, greaterThan(0));
    });

    test('losing to the AI loses points', () {
      final delta = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 2,
        result: const GameResult.win(Side.second, WinReason.score),
        humanSide: Side.first,
      );
      expect(delta, lessThan(0));
    });

    test('a draw at an equal virtual rating does not change the rating', () {
      final delta = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 2,
        result: const GameResult.draw(WinReason.score),
        humanSide: Side.first,
      );
      expect(delta, 0);
    });

    test('beating a harder AI gains more than beating an easier one', () {
      final vsHard = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 3,
        result: const GameResult.win(Side.first, WinReason.score),
        humanSide: Side.first,
      );
      final vsEasy = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 1,
        result: const GameResult.win(Side.first, WinReason.score),
        humanSide: Side.first,
      );
      expect(vsHard, greaterThan(vsEasy));
    });

    test('resignation (winner is the opponent) loses points like any loss',
        () {
      final delta = computeReversiaRatingDelta(
        currentRating: 1200,
        aiLevel: 2,
        result: const GameResult.win(Side.second, WinReason.resignation),
        humanSide: Side.first,
      );
      expect(delta, lessThan(0));
    });
  });
}
