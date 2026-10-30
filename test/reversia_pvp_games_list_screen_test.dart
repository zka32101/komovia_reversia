import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_games_list_screen.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required ReversiaPvpGameService service,
    String uid = 'u1',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reversiaPvpGameServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReversiaPvpGamesListScreen(uid: uid)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when there are no active games', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await pumpScreen(tester, service: ReversiaPvpGameService(firestore));

    expect(find.text('進行中のPvP対局はありません'), findsOneWidget);
  });

  testWidgets('lists an active game where the user is Side.first', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    await service.createGame(
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
    );

    await pumpScreen(tester, service: service);

    expect(find.text('vs Bob'), findsOneWidget);
    expect(find.text('あなたの番'), findsOneWidget);
  });

  testWidgets('lists an active game where the user is Side.second, showing the opponent turn label', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    await service.createGame(
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
    );

    await pumpScreen(tester, service: service, uid: 'u2');

    expect(find.text('vs Alice'), findsOneWidget);
    expect(find.text('相手の番'), findsOneWidget);
  });

  testWidgets('does not list a finished game', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final game = await service.createGame(
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
    );
    await service.resign(gameId: game.id, uid: 'u1');

    await pumpScreen(tester, service: service);

    expect(find.text('進行中のPvP対局はありません'), findsOneWidget);
  });

  testWidgets('tapping a game card opens its ReversiaPvpGameScreen', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    await service.createGame(
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
    );

    await pumpScreen(tester, service: service);
    await tester.tap(find.text('vs Bob'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
  });

  testWidgets('shows a forfeit-claim button for a stale game and claiming it removes it from the list', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaPvpGameService(firestore);
    final game = await service.createGame(
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
    );
    // first-uid's turn, so second-uid (u2) is waiting and eligible to claim.
    await firestore.collection('reversia_pvp_games').doc(game.id).update({
      'updatedAt': Timestamp.fromDate(
        DateTime.now().subtract(
          ReversiaPvpGameService.abandonmentThreshold + const Duration(hours: 1),
        ),
      ),
    });

    await pumpScreen(tester, service: service, uid: 'u2');
    expect(find.text('放置勝ちを申請する'), findsOneWidget);

    await tester.tap(find.text('放置勝ちを申請する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申請する'));
    await tester.pumpAndSettle();

    expect(find.text('進行中のPvP対局はありません'), findsOneWidget);
  });
}
