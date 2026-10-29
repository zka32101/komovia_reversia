import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/friend_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/friend_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/views/screens/live_friends_screen.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';

void main() {
  Future<void> seedUser(FakeFirebaseFirestore firestore, String uid, String name) async {
    await firestore.collection('users').doc(uid).set({'displayName': name});
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeFirebaseFirestore firestore,
    String uid = 'user1234',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue(uid),
          friendServiceProvider.overrideWithValue(FriendService(firestore: firestore)),
          reversiaPvpGameServiceProvider
              .overrideWithValue(ReversiaPvpGameService(firestore)),
        ],
        child: MaterialApp(home: LiveFriendsScreen(uid: uid)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when no friend is playing', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedUser(firestore, 'user1234', 'Alice');
    await pumpScreen(tester, firestore: firestore);

    expect(find.text('いま対局中のフレンドはいません'), findsOneWidget);
  });

  testWidgets('lists a friend currently playing, opening the game on tap', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final friendService = FriendService(firestore: firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    await seedUser(firestore, 'user1234', 'Alice');
    await seedUser(firestore, 'friend001', 'Bob');
    await friendService.sendRequest('user1234', 'Alice', 'friend001');
    await friendService.acceptRequest('friend001', 'user1234');
    await pvpService.createGame(
      firstUid: 'friend001',
      firstDisplayName: 'Bob',
      secondUid: 'stranger1',
      secondDisplayName: 'Carol',
    );

    await pumpScreen(tester, firestore: firestore);

    expect(find.text('Bob'), findsOneWidget);

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
    expect(find.text('観戦中'), findsOneWidget);
  });
}
