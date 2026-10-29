import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/direct_message_service.dart';
import 'package:komovia_reversia/services/friend_service.dart';
import 'package:komovia_reversia/services/leaderboard_service.dart';
import 'package:komovia_reversia/services/notification_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/services/tournament_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/direct_message_provider.dart';
import 'package:komovia_reversia/viewmodels/friend_provider.dart';
import 'package:komovia_reversia/viewmodels/leaderboard_provider.dart';
import 'package:komovia_reversia/viewmodels/notification_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/viewmodels/tournament_provider.dart';
import 'package:komovia_reversia/views/screens/friends_screen.dart';
import 'package:komovia_reversia/views/screens/home_screen.dart';
import 'package:komovia_reversia/views/screens/leaderboard_screen.dart';
import 'package:komovia_reversia/views/screens/message_threads_screen.dart';
import 'package:komovia_reversia/views/screens/puzzle_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_matching_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_games_list_screen.dart';
import 'package:komovia_reversia/views/screens/settings_screen.dart';
import 'package:komovia_reversia/views/screens/tournament_screen.dart';

void main() {
  // real Firebase providers (notifications/leaderboard/PvP list) all take
  // an injectable FirebaseFirestore, so every pump here shares one fake
  // instance instead of touching FirebaseFirestore.instance (uninitialized
  // in a plain `flutter test`).
  Future<void> pumpHome(
    WidgetTester tester, {
    String? uid,
    VoidCallback? onPlayReversia,
  }) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue(uid),
          notificationServiceProvider
              .overrideWithValue(NotificationService(firestore: firestore)),
          leaderboardServiceProvider
              .overrideWithValue(LeaderboardService(firestore: firestore)),
          reversiaPvpGameServiceProvider
              .overrideWithValue(ReversiaPvpGameService(firestore)),
          friendServiceProvider
              .overrideWithValue(FriendService(firestore: firestore)),
          directMessageServiceProvider
              .overrideWithValue(DirectMessageService(firestore: firestore)),
          tournamentServiceProvider
              .overrideWithValue(TournamentService(firestore: firestore)),
        ],
        child: MaterialApp(
          home: HomeScreen(onPlayReversia: onPlayReversia ?? () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('always shows プレイ, 今日の1局, ランキング and 設定 tiles', (tester) async {
    await pumpHome(tester, uid: null);

    expect(find.text('プレイ'), findsOneWidget);
    expect(find.text('今日の1局'), findsOneWidget);
    expect(find.text('ランキング'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('hides the matching/PvP-list tiles and notification bell when signed out', (
    tester,
  ) async {
    await pumpHome(tester, uid: null);

    expect(find.text('対局相手を探す'), findsNothing);
    expect(find.text('対局中のPvP'), findsNothing);
    expect(find.text('フレンド'), findsNothing);
    expect(find.text('トーナメント'), findsNothing);
    expect(find.byIcon(Icons.notifications), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
  });

  testWidgets('shows the matching/PvP-list/friends/tournament tiles and notification/message icons when signed in', (
    tester,
  ) async {
    await pumpHome(tester, uid: 'user1234');

    expect(find.text('対局相手を探す'), findsOneWidget);
    expect(find.text('対局中のPvP'), findsOneWidget);
    expect(find.text('フレンド'), findsOneWidget);
    expect(find.text('トーナメント'), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
  });

  testWidgets('tapping プレイ invokes onPlayReversia', (tester) async {
    var tapped = false;
    await pumpHome(tester, uid: null, onPlayReversia: () => tapped = true);

    await tester.tap(find.text('プレイ'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tapping 今日の1局 opens PuzzleScreen', (tester) async {
    await pumpHome(tester, uid: null);

    await tester.tap(find.text('今日の1局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PuzzleScreen), findsOneWidget);
  });

  testWidgets('tapping 対局相手を探す opens ReversiaMatchingScreen', (tester) async {
    await pumpHome(tester, uid: 'user1234');

    await tester.tap(find.text('対局相手を探す'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReversiaMatchingScreen), findsOneWidget);
  });

  testWidgets('tapping 対局中のPvP opens ReversiaPvpGamesListScreen', (tester) async {
    await pumpHome(tester, uid: 'user1234');

    await tester.tap(find.text('対局中のPvP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReversiaPvpGamesListScreen), findsOneWidget);
  });

  testWidgets('tapping フレンド opens FriendsScreen', (tester) async {
    await pumpHome(tester, uid: 'user1234');

    await tester.tap(find.text('フレンド'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FriendsScreen), findsOneWidget);
  });

  testWidgets('tapping トーナメント opens TournamentScreen', (tester) async {
    await pumpHome(tester, uid: 'user1234');

    await tester.tap(find.text('トーナメント'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TournamentScreen), findsOneWidget);
  });

  testWidgets('tapping the mail icon opens MessageThreadsScreen', (tester) async {
    await pumpHome(tester, uid: 'user1234');

    await tester.tap(find.byIcon(Icons.mail_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MessageThreadsScreen), findsOneWidget);
  });

  testWidgets('tapping ランキング opens LeaderboardScreen', (tester) async {
    await pumpHome(tester, uid: null);

    await tester.tap(find.text('ランキング'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LeaderboardScreen), findsOneWidget);
  });

  testWidgets('tapping 設定 opens SettingsScreen', (tester) async {
    await pumpHome(tester, uid: null);

    await tester.tap(find.text('設定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
