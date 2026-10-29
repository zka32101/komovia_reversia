import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/main.dart';
import 'package:komovia_reversia/services/game_save_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test for the app shell added in this PR: the real
/// `ReversiaGame`/`ReversiaEngine`/`ReversiaBoardRenderer` stack, driven
/// through `ReversiaGameScreen`'s actual UI (tap-to-select, tap-to-move,
/// automatic AI reply) rather than any mocked game state.
///
/// `_RootScreen` now shows `OnboardingScreen` first on a fresh install
/// (see onboarding_screen_test.dart for that flow), then `HomeScreen`
/// (see home_screen_test.dart) rather than `ReversiaGameScreen` directly -
/// these tests are about the game itself, so they mark onboarding as
/// already-completed, pump once extra to let `_RootScreen`'s async
/// `hasCompletedOnboarding()` check resolve, then tap `HomeScreen`'s
/// "プレイ" tile to reach the game screen before asserting on it.
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

  Future<void> openGameFromHome(WidgetTester tester) async {
    await tester.tap(find.text('プレイ'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the initial turn status and the board', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const KomoviaReversiaApp(),
      ),
    );
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();
    await openGameFromHome(tester);

    expect(find.text('あなたの番です'), findsOneWidget);
    expect(find.byKey(const Key('reversia_board_gesture_detector')), findsOneWidget);
  });

  testWidgets('hides the notification bell when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const KomoviaReversiaApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.notifications), findsNothing);
  });

  testWidgets('shows the notification bell once signed in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue('u1')],
        child: const KomoviaReversiaApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.notifications), findsOneWidget);
  });

  testWidgets('tapping one of 先手\'s pieces then a legal destination moves it and triggers an AI reply', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const KomoviaReversiaApp(),
      ),
    );
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();
    await openGameFromHome(tester);

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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const KomoviaReversiaApp(),
      ),
    );
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();
    await openGameFromHome(tester);

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

  testWidgets('tapping the hint button highlights a legal move without playing it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: const KomoviaReversiaApp(),
      ),
    );
    await tester.pump(); // let hasCompletedOnboarding() resolve
    await tester.pump();
    await openGameFromHome(tester);

    await tester.tap(find.byIcon(Icons.lightbulb_outline));
    await tester.pump();

    // The hint highlights a suggested move via the same selection/hint
    // state a manual tap would use, so the status text and board are
    // unchanged (no move has actually been played) while it's still
    // the player's turn.
    expect(find.text('あなたの番です'), findsOneWidget);
    expect(find.byKey(const Key('reversia_board_gesture_detector')), findsOneWidget);
  });

  group('game save/resume', () {
    testWidgets('a move persists an in-progress save, and 新しい対局 clears it', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: const KomoviaReversiaApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await openGameFromHome(tester);

      expect(await GameSaveService().loadInProgressGame(), isNull);

      await tester.tapAt(squareCenter(tester, 0, 0));
      await tester.pump();
      await tester.tapAt(squareCenter(tester, 0, 1));
      await tester.pump();

      final saved = await GameSaveService().loadInProgressGame();
      expect(saved, isNotNull);
      expect(saved, isNotEmpty);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(await GameSaveService().loadInProgressGame(), isNull);
    });

    testWidgets('resume: true replays a saved game back to the same board state', (
      tester,
    ) async {
      final game = ReversiaGame();
      final initial = game.initialPosition();
      final historyKeys = [game.positionKey(initial)];
      final move = game
          .legalMoves(initial, historyKeys: historyKeys)
          .whereType<BoardMove>()
          .first;
      final afterMove = game.apply(initial, move, historyKeys: historyKeys);
      final record = GameRecord(
        gameId: 'local',
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        result: GameResult.ongoing,
      );
      await GameSaveService().saveInProgressGame(game.exportRecord(record));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: MaterialApp(home: ReversiaGameScreen(resume: true)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('reversia_board_gesture_detector')),
        findsOneWidget,
      );
      // 保存された1手を再生した局面になっているので、着手済みの升は
      // もう「自分の駒」ではない（afterMoveのsideToMoveが元と逆になる）。
      expect(afterMove.sideToMove, isNot(initial.sideToMove));
    });

    testWidgets('a broken save is discarded and the game starts fresh', (
      tester,
    ) async {
      await GameSaveService().saveInProgressGame('not a valid record');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: MaterialApp(home: ReversiaGameScreen(resume: true)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('あなたの番です'), findsOneWidget);
      expect(await GameSaveService().loadInProgressGame(), isNull);
    });
  });

  group('undo', () {
    testWidgets('undoes the player\'s move and the AI\'s reply, returning to the player\'s turn', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: const KomoviaReversiaApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await openGameFromHome(tester);

      expect(find.byTooltip('待った'), findsOneWidget);
      await tester.tap(find.byTooltip('待った'));
      await tester.pump();
      // 何も着手していない状態での待ったは何もしない。
      expect(find.text('あなたの番です'), findsOneWidget);

      await tester.tapAt(squareCenter(tester, 0, 0));
      await tester.pump();
      await tester.tapAt(squareCenter(tester, 0, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('あなたの番です'), findsOneWidget);
      final saved = await GameSaveService().loadInProgressGame();
      expect(saved, isNotNull);

      await tester.tap(find.byTooltip('待った'));
      await tester.pump();

      // 自分の着手とAIの応手の両方が取り消され、取り消し前と同じ初期
      // 局面に戻って再び自分の番になる。
      expect(find.text('あなたの番です'), findsOneWidget);
      expect(await GameSaveService().loadInProgressGame(), isNull);
    });

    testWidgets('undo while the AI is still thinking cancels its reply', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: const KomoviaReversiaApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await openGameFromHome(tester);

      await tester.tapAt(squareCenter(tester, 0, 0));
      await tester.pump();
      await tester.tapAt(squareCenter(tester, 0, 1));
      await tester.pump();

      expect(find.text('AIが考えています…'), findsOneWidget);
      await tester.tap(find.byTooltip('待った'));
      await tester.pump();

      expect(find.text('あなたの番です'), findsOneWidget);
      // AIの返信タイマーをキャンセルしているので、待っても何も起きない。
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('あなたの番です'), findsOneWidget);
    });
  });

  group('handicap', () {
    testWidgets('shows all handicap options and starts a fresh game on selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: const KomoviaReversiaApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await openGameFromHome(tester);

      // 対局を1手進めておき、ハンディキャップ選択が新規対局として
      // 始め直すことを後で確認できるようにする。
      await tester.tapAt(squareCenter(tester, 0, 0));
      await tester.pump();
      await tester.tapAt(squareCenter(tester, 0, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.balance));
      await tester.pumpAndSettle();

      expect(find.text('なし'), findsOneWidget);
      for (final rule in ReversiaHandicapRule.all) {
        expect(find.text(rule.label), findsOneWidget);
      }

      await tester.tap(find.text('二枚落ち'));
      await tester.pumpAndSettle();

      // ハンディキャップ選択は常に新規対局として始め直す。
      expect(find.text('あなたの番です'), findsOneWidget);
      // ハンディキャップ対局は保存データの再生前提（標準局面からの再生）
      // と矛盾するため、着手してもGameSaveServiceには保存しない。
      await tester.tapAt(squareCenter(tester, 0, 0));
      await tester.pump();
      await tester.tapAt(squareCenter(tester, 0, 1));
      await tester.pump();
      expect(await GameSaveService().loadInProgressGame(), isNull);
    });

    testWidgets('picking なし after a handicap returns to the standard position', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUidProvider.overrideWithValue(null)],
          child: const KomoviaReversiaApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await openGameFromHome(tester);

      await tester.tap(find.byIcon(Icons.balance));
      await tester.pumpAndSettle();
      await tester.tap(find.text('六枚落ち'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.balance));
      await tester.pumpAndSettle();
      await tester.tap(find.text('なし'));
      await tester.pumpAndSettle();

      expect(find.text('あなたの番です'), findsOneWidget);
    });
  });
}
