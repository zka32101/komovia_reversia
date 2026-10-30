import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/notification_service.dart';
import 'package:komovia_reversia/services/reversia_challenge_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/notification_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_challenge_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/views/screens/reversia_challenge_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required ReversiaChallengeService challengeService,
    required ReversiaPvpGameService pvpService,
    NotificationService? notificationService,
    String uid = 'u1',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reversiaChallengeServiceProvider.overrideWithValue(challengeService),
          reversiaPvpGameServiceProvider.overrideWithValue(pvpService),
          currentUidProvider.overrideWithValue(uid),
          if (notificationService != null)
            notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReversiaChallengeScreen(uid: uid, displayName: 'Alice'),
        ),
      ),
    );
    await tester.pump();
  }

  // 「コードを発行する」/「参加する」はFirestore(フェイク)への非同期
  // 書き込みを挟んでsetStateするため、既存のreversia_matching_screen_test
  // と同じ回避パターンを使う。
  Future<void> waitForAsyncWork(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('creating a code shows it on a waiting card', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final challengeService = ReversiaChallengeService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);

    await pumpScreen(
      tester,
      challengeService: challengeService,
      pvpService: pvpService,
    );
    await tester.tap(find.text('コードを発行する'));
    await waitForAsyncWork(tester);

    expect(find.text('このコードを相手に伝えてください'), findsOneWidget);
    final codeDoc =
        (await firestore.collection('reversia_challenge_codes').get()).docs.single;
    expect(find.text(codeDoc.id), findsOneWidget);
  });

  testWidgets('entering a valid code joins and shows the waiting state', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final challengeService = ReversiaChallengeService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    final hostChallenge = await challengeService.createChallenge(
      hostUid: 'host-uid',
      hostDisplayName: 'Host',
    );

    await pumpScreen(
      tester,
      challengeService: challengeService,
      pvpService: pvpService,
    );
    await tester.enterText(find.byType(TextField), hostChallenge.code);
    await tester.tap(find.text('参加する'));
    await waitForAsyncWork(tester);

    expect(find.text('対局相手を待っています…'), findsOneWidget);
  });

  testWidgets('an invalid code shows an error instead of joining', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final challengeService = ReversiaChallengeService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);

    await pumpScreen(
      tester,
      challengeService: challengeService,
      pvpService: pvpService,
    );
    await tester.enterText(find.byType(TextField), 'NOCODE');
    await tester.tap(find.text('参加する'));
    await waitForAsyncWork(tester);

    expect(find.textContaining('無効'), findsOneWidget);
  });

  testWidgets(
      'once a guest joins the host\'s code, the host creates the game and navigates in',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final challengeService = ReversiaChallengeService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);

    await pumpScreen(
      tester,
      challengeService: challengeService,
      pvpService: pvpService,
      uid: 'host-uid',
    );
    await tester.tap(find.text('コードを発行する'));
    await waitForAsyncWork(tester);

    final codeDoc =
        (await firestore.collection('reversia_challenge_codes').get()).docs.single;

    // 別デバイスからゲストが同じコードに参加した状況を、サービスへの
    // 直接呼び出しでシミュレートする。
    await challengeService.joinChallenge(
      code: codeDoc.id,
      guestUid: 'guest-uid',
      guestDisplayName: 'Bob',
    );
    await waitForAsyncWork(tester);
    await waitForAsyncWork(tester);

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
    final game = await pvpService.getGame(
      (await challengeService.getChallenge(codeDoc.id))!.gameId!,
    );
    expect(game!.firstUid, 'host-uid');
    expect(game.secondUid, 'guest-uid');
  });

  testWidgets('the host notifies the guest once the game is created',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final challengeService = ReversiaChallengeService(firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    final notificationService = NotificationService(firestore: firestore);

    await pumpScreen(
      tester,
      challengeService: challengeService,
      pvpService: pvpService,
      notificationService: notificationService,
      uid: 'host-uid',
    );
    await tester.tap(find.text('コードを発行する'));
    await waitForAsyncWork(tester);
    final codeDoc =
        (await firestore.collection('reversia_challenge_codes').get()).docs.single;

    await challengeService.joinChallenge(
      code: codeDoc.id,
      guestUid: 'guest-uid',
      guestDisplayName: 'Bob',
    );
    await waitForAsyncWork(tester);
    await waitForAsyncWork(tester);

    final notifications = await notificationService.getNotifications('guest-uid');
    expect(notifications, hasLength(1));
    expect(notifications.single.type, 'pvp_challenge');
  });
}
