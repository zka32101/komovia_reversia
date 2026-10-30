import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/views/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';

/// [OnboardingScreen] exercised through its real UI (not mocked): two
/// explanation pages, then a real interactive mini board where tapping the
/// front-facing piece then the opponent's square actually captures it
/// through `ReversiaGame.apply` — mirroring komovia_shogi's own
/// `onboarding_screen_test.dart`.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Offset squareCenter(WidgetTester tester, int file, int rank) {
    const boardSize = 320.0; // the demo board's own clamp(0, 320)
    const cellSize = boardSize / 6;
    final local = Offset(cellSize * (file + 0.5), cellSize * (rank + 0.5));
    return tester.getTopLeft(
          find.byKey(const Key('onboarding_board_gesture_detector')),
        ) +
        local;
  }

  testWidgets('walks through both explanation pages to the capture demo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () {})),
    );

    expect(find.text('駒の動かし方'), findsOneWidget);
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    expect(find.text('勝敗'), findsOneWidget);
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    expect(find.text('表向きの駒をタップして、すぐ上の相手の駒を取ってみましょう'), findsOneWidget);
  });

  testWidgets(
      '「はじめる」 is disabled until the demo piece is actually captured', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () {})),
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'はじめる'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets(
      'tapping the front-facing piece then the opponent square captures it and enables 「はじめる」',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () {})),
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    // The demo position places 先手's piece at file 2, rank 3 and 後手's
    // piece directly above at file 2, rank 2 (onboarding_demo.dart).
    await tester.tapAt(squareCenter(tester, 2, 3));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 2, 2));
    await tester.pump();

    expect(find.text('やった、1枚取れました！'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'はじめる'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('finishing the demo calls onFinished and marks onboarding complete',
      (tester) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () => finished = true),
      ),
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tapAt(squareCenter(tester, 2, 3));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 2, 2));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'はじめる'));
    await tester.pump();

    expect(finished, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });
}
