import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test for the app shell added in this PR: the real
/// `ReversiaGame`/`ReversiaEngine`/`ReversiaBoardRenderer` stack, driven
/// through `ReversiaGameScreen`'s actual UI (tap-to-select, tap-to-move,
/// automatic AI reply) rather than any mocked game state.
///
/// `_RootScreen` now shows `OnboardingScreen` first on a fresh install
/// (see onboarding_screen_test.dart for that flow) - these tests are about
/// the game itself, so they mark onboarding as already-completed and pump
/// once extra to let `_RootScreen`'s async `hasCompletedOnboarding()`
/// check resolve before asserting on the game screen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
  });

  Offset squareCenter(WidgetTester tester, int file, int rank) {
    const cellSize = 400.0 / ReversiaPosition.boardSize;
    final local = Offset(cellSize * (file + 0.5), cellSize * (rank + 0.5));
    return tester.getTopLeft(find.byKey(const Key('reversia_board_gesture_detector'))) +
        local;
  }

  testWidgets('shows the initial turn status and the board', (tester) async {
    await tester.pumpWidget(const KomoviaReversiaApp());
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();

    expect(find.text('あなたの番です'), findsOneWidget);
    expect(find.byKey(const Key('reversia_board_gesture_detector')), findsOneWidget);
  });

  testWidgets('tapping one of 先手\'s pieces then a legal destination moves it and triggers an AI reply', (tester) async {
    await tester.pumpWidget(const KomoviaReversiaApp());
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();

    // ReversiaGame.initialPosition places 先手's front row at rank 0 — any
    // piece there has at least one legal orthogonal move (row 1 is only
    // partially occupied, by 先手's own second row at columns 1-3).
    await tester.tapAt(squareCenter(tester, 0, 0));
    await tester.pump();

    await tester.tapAt(squareCenter(tester, 0, 1));
    await tester.pump();

    // The move hands the turn to the AI (後手), which replies after its
    // scheduled delay.
    expect(find.text('AIが考えています…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('あなたの番です'), findsOneWidget);
  });

  testWidgets('"新しい対局" resets to the initial position after moves have been played', (tester) async {
    await tester.pumpWidget(const KomoviaReversiaApp());
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();

    await tester.tapAt(squareCenter(tester, 0, 0));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 0, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(find.text('あなたの番です'), findsOneWidget);
  });
}
