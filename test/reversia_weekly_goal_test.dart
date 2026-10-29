import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/models/reversia_weekly_progress.dart';

void main() {
  group('reversiaWeekId', () {
    test('a Wednesday and the preceding Monday share the same week id', () {
      final wednesday = DateTime(2026, 10, 28); // a Wednesday
      final monday = DateTime(2026, 10, 26);
      expect(reversiaWeekId(wednesday), reversiaWeekId(monday));
      expect(reversiaWeekId(monday), '2026-10-26');
    });

    test('a Sunday belongs to the week starting the previous Monday', () {
      final sunday = DateTime(2026, 11, 1);
      expect(reversiaWeekId(sunday), '2026-10-26');
    });

    test('the following Monday starts a new week id', () {
      final nextMonday = DateTime(2026, 11, 2);
      expect(reversiaWeekId(nextMonday), '2026-11-02');
    });
  });

  group('ReversiaWeeklyGoal', () {
    test('progressOf is clamped to 1.0 even past the target', () {
      const progress = ReversiaWeeklyProgress(gamesPlayed: 10, wins: 0, puzzlesSolved: 0);
      final goal = ReversiaWeeklyGoal.all.firstWhere((g) => g.id == 'play3');
      expect(goal.progressOf(progress), 1.0);
      expect(goal.isCompletedBy(progress), isTrue);
    });

    test('progressOf is a fraction below the target', () {
      const progress = ReversiaWeeklyProgress(gamesPlayed: 1, wins: 0, puzzlesSolved: 0);
      final goal = ReversiaWeeklyGoal.all.firstWhere((g) => g.id == 'play3');
      expect(goal.progressOf(progress), closeTo(1 / 3, 0.001));
      expect(goal.isCompletedBy(progress), isFalse);
    });

    test('each goal reads the field it claims to', () {
      const progress = ReversiaWeeklyProgress(gamesPlayed: 1, wins: 2, puzzlesSolved: 3);
      expect(
        ReversiaWeeklyGoal.all.firstWhere((g) => g.id == 'play3').valueOf(progress),
        1,
      );
      expect(
        ReversiaWeeklyGoal.all.firstWhere((g) => g.id == 'win2').valueOf(progress),
        2,
      );
      expect(
        ReversiaWeeklyGoal.all.firstWhere((g) => g.id == 'puzzle3').valueOf(progress),
        3,
      );
    });
  });
}
