import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/services/reversia_puzzle_log_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_puzzle_log_provider.dart';
import 'package:komovia_reversia/views/screens/puzzle_screen.dart';

/// Drives [PuzzleScreen] through its real UI against today's actual puzzle
/// (`reversiaPuzzleForDate(DateTime.now())`), rather than a fixed/mocked
/// position - the puzzle shown varies by day, so tap coordinates are
/// derived from the puzzle's own solution move, not hardcoded squares.
void main() {
  Offset squareCenter(WidgetTester tester, Square square) {
    const boardSize = 400.0; // the puzzle board's own clamp(0, 400)
    const cellSize = boardSize / ReversiaPosition.boardSize;
    final local = Offset(
      cellSize * (square.file + 0.5),
      cellSize * (square.rank + 0.5),
    );
    return tester.getTopLeft(
          find.byKey(const Key('puzzle_board_gesture_detector')),
        ) +
        local;
  }

  late Puzzle<ReversiaPosition> todaysPuzzle;
  late BoardMove solutionMove;

  setUp(() {
    todaysPuzzle = reversiaPuzzleForDate(DateTime.now());
    solutionMove = todaysPuzzle.solution.single as BoardMove;
  });

  testWidgets('shows the prompt and the board before any move', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PuzzleScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('駒をタップして選び、行き先をタップしてください'), findsOneWidget);
    expect(find.byKey(const Key('puzzle_board_gesture_detector')), findsOneWidget);
  });

  testWidgets('playing the real solution move shows the correct banner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PuzzleScreen()),
      ),
    );
    await tester.pump();

    await tester.tapAt(squareCenter(tester, solutionMove.from));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, solutionMove.to));
    await tester.pump();

    expect(find.text('正解です！'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'もう一度'), findsNothing);
  });

  testWidgets('playing a wrong move shows the incorrect banner and a retry button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PuzzleScreen()),
      ),
    );
    await tester.pump();

    // Every puzzle's doc comment guarantees at least one non-winning
    // legal move exists (a decoy piece, or another destination from the
    // same piece) - any legal move other than the real solution is a
    // legal-but-wrong attempt.
    final game = ReversiaGame();
    final decoy = game
        .legalMoves(todaysPuzzle.position)
        .whereType<BoardMove>()
        .firstWhere((m) => m != solutionMove);

    await tester.tapAt(squareCenter(tester, decoy.from));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, decoy.to));
    await tester.pump();

    expect(find.text('残念、違う手です'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'もう一度'), findsOneWidget);
  });

  testWidgets('「もう一度」resets the board after a wrong attempt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PuzzleScreen()),
      ),
    );
    await tester.pump();

    final game = ReversiaGame();
    final decoy = game
        .legalMoves(todaysPuzzle.position)
        .whereType<BoardMove>()
        .firstWhere((m) => m != solutionMove);

    await tester.tapAt(squareCenter(tester, decoy.from));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, decoy.to));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'もう一度'));
    await tester.pump();

    expect(find.text('駒をタップして選び、行き先をタップしてください'), findsOneWidget);
  });

  testWidgets('shows no streak chip when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PuzzleScreen()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets(
      'solving the puzzle correctly records today\'s attempt and raises the streak',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final puzzleLogService = ReversiaPuzzleLogService(firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('u1'),
          reversiaPuzzleLogServiceProvider.overrideWithValue(puzzleLogService),
        ],
        child: const MaterialApp(home: PuzzleScreen()),
      ),
    );
    await tester.pump();

    await tester.tapAt(squareCenter(tester, solutionMove.from));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, solutionMove.to));
    await tester.pumpAndSettle();

    final dateKey = formatReversiaPuzzleDateKey(DateTime.now());
    final log = await puzzleLogService.getLog('u1', dateKey);
    expect(log, isNotNull);
    expect(log!.solved, isTrue);
    expect(find.text('1日連続'), findsOneWidget);
  });
}
