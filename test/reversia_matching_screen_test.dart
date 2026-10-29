import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/notification_service.dart';
import 'package:komovia_reversia/services/reversia_matching_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/notification_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_matching_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/views/screens/reversia_matching_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required ReversiaMatchingService matchingService,
    required ReversiaPvpGameService pvpService,
    NotificationService? notificationService,
    String uid = 'u1',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reversiaMatchingServiceProvider.overrideWithValue(matchingService),
          reversiaPvpGameServiceProvider.overrideWithValue(pvpService),
          currentUidProvider.overrideWithValue(uid),
          if (notificationService != null)
            notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: MaterialApp(
          home: ReversiaMatchingScreen(uid: uid, displayName: 'Alice'),
        ),
      ),
    );
    await tester.pump();
  }

  // 「対局相手を探す」/「対局を開始する」はFirestore(フェイク)への非同期
  // 書き込みを挟んでsetStateするため、ボタン押下直後は`_isSearching`/
  // `_isStartingGame`のCircularProgressIndicator（常時アニメーション）が
  // 出る。pumpAndSettleはそれをブロックしうるので、固定回数のpump→実際の
  // 非同期完了待ち、という既存テストと同じ回避パターンを使う。
  Future<void> waitForAsyncWork(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('shows "no match found" when the queue is otherwise empty', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final matchingService = ReversiaMatchingService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);

    await pumpScreen(
      tester,
      matchingService: matchingService,
      pvpService: pvpService,
    );
    await tester.tap(find.widgetWithText(FilledButton, '対局相手を探す'));
    await waitForAsyncWork(tester);

    expect(find.textContaining('見つかりませんでした'), findsOneWidget);
  });

  testWidgets(
      'finding a waiting opponent shows the match-found card with a start button',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final matchingService = ReversiaMatchingService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    await matchingService.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);

    await pumpScreen(
      tester,
      matchingService: matchingService,
      pvpService: pvpService,
    );
    await tester.tap(find.widgetWithText(FilledButton, '対局相手を探す'));
    await waitForAsyncWork(tester);

    // "Bob" now appears both in the match-found card and (since finding a
    // match also records it) in the match history list below it.
    expect(find.textContaining('Bob'), findsWidgets);
    expect(find.text('対局を開始する'), findsOneWidget);
  });

  testWidgets(
      'starting the game creates a ReversiaPvpGame and navigates to ReversiaPvpGameScreen',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final matchingService = ReversiaMatchingService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    await matchingService.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);

    await pumpScreen(
      tester,
      matchingService: matchingService,
      pvpService: pvpService,
    );
    await tester.tap(find.widgetWithText(FilledButton, '対局相手を探す'));
    await waitForAsyncWork(tester);

    await tester.tap(find.text('対局を開始する'));
    await waitForAsyncWork(tester);

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
    final history = await matchingService.getMatchHistory('u1');
    expect(history.single.gameId, isNotNull);
  });

  testWidgets('starting the game notifies the opponent', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final matchingService = ReversiaMatchingService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    final notificationService = NotificationService(firestore: firestore);
    await matchingService.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);

    await pumpScreen(
      tester,
      matchingService: matchingService,
      pvpService: pvpService,
      notificationService: notificationService,
    );
    await tester.tap(find.widgetWithText(FilledButton, '対局相手を探す'));
    await waitForAsyncWork(tester);
    await tester.tap(find.text('対局を開始する'));
    await waitForAsyncWork(tester);

    final notifications = await notificationService.getNotifications('u2');
    expect(notifications, hasLength(1));
    expect(notifications.single.type, 'pvp_challenge');
    expect(notifications.single.data?['gameId'], isNotNull);
  });

  testWidgets('match history lists a past match and opens its game on tap', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final matchingService = ReversiaMatchingService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    await matchingService.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);
    await matchingService.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);
    final match = await matchingService.findMatch(
      uid: 'u1',
      displayName: 'Alice',
      rating: 1200,
    );
    final game = await pvpService.createGame(
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
      matchId: match!.id,
    );
    await matchingService.attachGameToMatch(match.id, game.id);

    await pumpScreen(
      tester,
      matchingService: matchingService,
      pvpService: pvpService,
    );
    await tester.pump();

    expect(find.textContaining('Bob'), findsOneWidget);
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
  });
}
