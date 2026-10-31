import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';

void main() {
  Future<String> seedGame(ReversiaPvpGameService service) async {
    final game = await service.createGame(
      firstUid: 'first-uid',
      firstDisplayName: 'Alice',
      secondUid: 'second-uid',
      secondDisplayName: 'Bob',
    );
    return game.id;
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required String gameId,
    required ReversiaPvpGameService service,
    required String uid,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reversiaPvpGameServiceProvider.overrideWithValue(service),
          currentUidProvider.overrideWithValue(uid),
        ],
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReversiaPvpGameScreen(gameId: gameId)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the board and whose turn it is for Side.first', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'first-uid');

    expect(find.text('あなたの番です'), findsOneWidget);
    expect(
      find.byKey(const Key('reversia_pvp_board_gesture_detector')),
      findsOneWidget,
    );
    expect(find.text('投了する'), findsOneWidget);
  });

  testWidgets('shows the opponent is to move for Side.second', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'second-uid');

    expect(find.text('相手の番です'), findsOneWidget);
  });

  testWidgets('a legal tap-tap move is applied and the turn flips', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);
    final reversiaGame = ReversiaGame();
    final firstLegal = reversiaGame
        .legalMoves(reversiaGame.initialPosition())
        .whereType<BoardMove>()
        .first;

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'first-uid');

    final boardFinder =
        find.byKey(const Key('reversia_pvp_board_gesture_detector'));
    final topLeft = tester.getTopLeft(boardFinder);
    final size = tester.getSize(boardFinder);
    final cellSize = size.width / ReversiaPosition.boardSize;
    Offset centerOf(Square square) => topLeft +
        Offset(cellSize * (square.file + 0.5), cellSize * (square.rank + 0.5));

    await tester.tapAt(centerOf(firstLegal.from));
    await tester.pump();
    await tester.tapAt(centerOf(firstLegal.to));
    await tester.pump();
    await tester.pump();

    final fetched = await service.getGame(gameId);
    expect(fetched!.movesCount, 1);
    expect(find.text('相手の番です'), findsOneWidget);
  });

  testWidgets('resign ends the game and shows the loss message', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'first-uid');

    await tester.tap(find.text('投了する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投了する').last);
    await tester.pumpAndSettle();

    expect(find.text('あなたの負けです'), findsOneWidget);
    expect(find.text('投了する'), findsNothing);
  });

  testWidgets('shows no review button while the game is still active', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'first-uid');

    expect(find.text('対局を振り返る'), findsNothing);
  });

  testWidgets('shows a review button once finished and opens ReversiaGameReviewScreen', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);
    await service.resign(gameId: gameId, uid: 'second-uid');

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'first-uid');
    expect(find.text('対局を振り返る'), findsOneWidget);

    await tester.tap(find.text('対局を振り返る'));
    await tester.pumpAndSettle();

    expect(find.text('対局の振り返り'), findsOneWidget);
  });

  testWidgets('shows a spectator view for a non-participant uid', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(
      tester,
      gameId: gameId,
      service: service,
      uid: 'someone-else',
    );

    expect(find.text('観戦中'), findsOneWidget);
    expect(find.text('投了する'), findsNothing);
  });

  testWidgets('shows a login-required message when signed out', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reversiaPvpGameServiceProvider.overrideWithValue(service),
          currentUidProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReversiaPvpGameScreen(gameId: gameId)),
      ),
    );
    await tester.pump();

    expect(find.text('ログインが必要です'), findsOneWidget);
  });

  testWidgets(
      'shows the forfeit-claim button for the waiting player once stale enough',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);
    // first-uid's turn (createGame default), so second-uid is waiting.
    await firestore.collection('reversia_pvp_games').doc(gameId).update({
      'updatedAt': Timestamp.fromDate(
        DateTime.now().subtract(
          ReversiaPvpGameService.abandonmentPolicy.threshold + const Duration(hours: 1),
        ),
      ),
    });

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'second-uid');

    expect(find.text('放置勝ちを申請する'), findsOneWidget);
  });

  testWidgets('hides the forfeit-claim button before the threshold elapses',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'second-uid');

    expect(find.text('放置勝ちを申請する'), findsNothing);
    // 閾値は分単位なので、待っている側には分単位のカウントダウンが出る
    expect(find.textContaining('あと15分で放置勝ちを申請できます'), findsOneWidget);
  });

  testWidgets('shows no forfeit countdown to the player whose turn it is',
      (tester) async {
    final service = ReversiaPvpGameService(FakeFirebaseFirestore());
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'first-uid');

    expect(find.textContaining('放置勝ちを申請できます'), findsNothing);
    expect(find.text('放置勝ちを申請する'), findsNothing);
  });

  testWidgets('claiming forfeit ends the game as a win for the claimant',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final gameId = await seedGame(service);
    await firestore.collection('reversia_pvp_games').doc(gameId).update({
      'updatedAt': Timestamp.fromDate(
        DateTime.now().subtract(
          ReversiaPvpGameService.abandonmentPolicy.threshold + const Duration(hours: 1),
        ),
      ),
    });

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'second-uid');
    // 盤面の下にあるため、小さい画面ではスクロールして表示する
    await tester.ensureVisible(find.text('放置勝ちを申請する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放置勝ちを申請する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申請する'));
    await tester.pumpAndSettle();

    expect(find.text('相手の放置により、あなたの勝ちです'), findsOneWidget);
  });
}
