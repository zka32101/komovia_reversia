import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:test/test.dart';

void main() {
  final game = ReversiaGame();

  group('dailyReversiaPuzzles', () {
    test('every puzzle has exactly one winning move among its legal moves, '
        'and it captures the king', () {
      for (final puzzle in dailyReversiaPuzzles) {
        final legal = game.legalMoves(puzzle.position);
        expect(
          legal,
          contains(puzzle.solution.single),
          reason: '${puzzle.id}: solution must be a legal move',
        );

        final winningMoves = legal.where((move) {
          final after = game.apply(puzzle.position, move);
          final result = game.result(after);
          return result.kind == ResultKind.win && result.winner == puzzle.position.sideToMove;
        }).toList();

        expect(
          winningMoves,
          [puzzle.solution.single],
          reason: '${puzzle.id} must have exactly one winning move, and it must be the '
              'solution (not an accidental second way to win)',
        );

        final after = game.apply(puzzle.position, puzzle.solution.single);
        final result = game.result(after);
        expect(result.reason, WinReason.checkmate, reason: puzzle.id);
      }
    });

    test('ids are unique', () {
      final ids = dailyReversiaPuzzles.map((p) => p.id).toSet();
      expect(ids, hasLength(dailyReversiaPuzzles.length));
    });
  });

  group('reversiaPuzzleForDate', () {
    test('is deterministic for the same calendar date', () {
      final date = DateTime(2026, 3, 14);
      expect(reversiaPuzzleForDate(date).id, reversiaPuzzleForDate(date).id);
    });

    test('cycles through the full rotation over a year', () {
      final seen = <String>{};
      for (var day = 0; day < 365; day++) {
        seen.add(reversiaPuzzleForDate(DateTime(2026, 1, 1).add(Duration(days: day))).id);
      }
      expect(seen, dailyReversiaPuzzles.map((p) => p.id).toSet());
    });
  });

  group('formatReversiaPuzzleDateKey', () {
    test('zero-pads month and day', () {
      expect(formatReversiaPuzzleDateKey(DateTime(2026, 3, 4)), '2026-03-04');
    });
  });
}
