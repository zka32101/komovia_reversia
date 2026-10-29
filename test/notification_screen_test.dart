import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/notification_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/index.dart';
import 'package:komovia_reversia/views/screens/notification_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required NotificationService notificationService,
    required ReversiaPvpGameService pvpService,
    String uid = 'u1',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          reversiaPvpGameServiceProvider.overrideWithValue(pvpService),
        ],
        child: MaterialApp(home: NotificationScreen(uid: uid)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when there are no notifications', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await pumpScreen(
      tester,
      notificationService: NotificationService(firestore: firestore),
      pvpService: ReversiaPvpGameService(firestore),
    );

    expect(find.text('通知はありません'), findsOneWidget);
  });

  testWidgets('lists a notification with its title and body', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final notificationService = NotificationService(firestore: firestore);
    await notificationService.send(
      uid: 'u1',
      title: 'Aliceさんと対局が始まりました',
      body: 'タップして対局を開く',
      type: 'pvp_challenge',
    );

    await pumpScreen(
      tester,
      notificationService: notificationService,
      pvpService: ReversiaPvpGameService(firestore),
    );

    expect(find.text('Aliceさんと対局が始まりました'), findsOneWidget);
    expect(find.text('タップして対局を開く'), findsOneWidget);
  });

  testWidgets(
      'tapping a pvp_challenge notification marks it read and opens the game',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final notificationService = NotificationService(firestore: firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    final game = await pvpService.createGame(
      firstUid: 'u2',
      firstDisplayName: 'Alice',
      secondUid: 'u1',
      secondDisplayName: 'Bob',
    );
    await notificationService.send(
      uid: 'u1',
      title: 'Aliceさんと対局が始まりました',
      body: 'タップして対局を開く',
      type: 'pvp_challenge',
      data: {'gameId': game.id},
    );

    await pumpScreen(
      tester,
      notificationService: notificationService,
      pvpService: pvpService,
    );
    await tester.tap(find.text('Aliceさんと対局が始まりました'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
    final notification = (await notificationService.getNotifications('u1')).single;
    expect(notification.isRead, isTrue);
  });

  testWidgets('tapping a non-pvp_challenge notification does not navigate',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final notificationService = NotificationService(firestore: firestore);
    await notificationService.send(
      uid: 'u1',
      title: 'お知らせ',
      body: '本文',
      type: 'other',
    );

    await pumpScreen(
      tester,
      notificationService: notificationService,
      pvpService: ReversiaPvpGameService(firestore),
    );
    await tester.tap(find.text('お知らせ'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsNothing);
    final notification = (await notificationService.getNotifications('u1')).single;
    expect(notification.isRead, isTrue);
  });
}
