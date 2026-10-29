import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/models/reversia_difficulty_stats.dart';

void main() {
  group('recommendDifficultyChange', () {
    test('returns none when there are too few games', () {
      final stats = const ReversiaDifficultyStats({
        2: ReversiaLevelRecord(games: 3, wins: 3),
      });
      expect(
        recommendDifficultyChange(currentLevel: 2, stats: stats),
        ReversiaDifficultyAdvice.none,
      );
    });

    test('recommends moving up on a high win rate with enough games', () {
      final stats = const ReversiaDifficultyStats({
        2: ReversiaLevelRecord(games: 10, wins: 8),
      });
      expect(
        recommendDifficultyChange(currentLevel: 2, stats: stats),
        ReversiaDifficultyAdvice.moveUp,
      );
    });

    test('does not recommend moving up past the highest level', () {
      final stats = const ReversiaDifficultyStats({
        3: ReversiaLevelRecord(games: 10, wins: 9),
      });
      expect(
        recommendDifficultyChange(currentLevel: 3, stats: stats),
        ReversiaDifficultyAdvice.none,
      );
    });

    test('recommends moving down on a low win rate with enough games', () {
      final stats = const ReversiaDifficultyStats({
        2: ReversiaLevelRecord(games: 10, wins: 2),
      });
      expect(
        recommendDifficultyChange(currentLevel: 2, stats: stats),
        ReversiaDifficultyAdvice.moveDown,
      );
    });

    test('does not recommend moving down past the lowest level', () {
      final stats = const ReversiaDifficultyStats({
        1: ReversiaLevelRecord(games: 10, wins: 1),
      });
      expect(
        recommendDifficultyChange(currentLevel: 1, stats: stats),
        ReversiaDifficultyAdvice.none,
      );
    });

    test('returns none for a middling win rate', () {
      final stats = const ReversiaDifficultyStats({
        2: ReversiaLevelRecord(games: 10, wins: 5),
      });
      expect(
        recommendDifficultyChange(currentLevel: 2, stats: stats),
        ReversiaDifficultyAdvice.none,
      );
    });
  });

  group('reversiaDifficultyAdviceMessage', () {
    test('returns null for none', () {
      expect(reversiaDifficultyAdviceMessage(ReversiaDifficultyAdvice.none, 2), isNull);
    });

    test('names the next level up', () {
      final message = reversiaDifficultyAdviceMessage(ReversiaDifficultyAdvice.moveUp, 2);
      expect(message, contains('上級'));
    });

    test('names the level down', () {
      final message = reversiaDifficultyAdviceMessage(ReversiaDifficultyAdvice.moveDown, 2);
      expect(message, contains('初級'));
    });
  });
}
