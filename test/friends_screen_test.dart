import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/friend_service.dart';
import 'package:komovia_reversia/viewmodels/friend_provider.dart';
import 'package:komovia_reversia/views/screens/friends_screen.dart';

void main() {
  Future<FriendService> pumpFriends(
    WidgetTester tester, {
    required String uid,
    String displayName = 'Alice',
  }) async {
    final firestore = FakeFirebaseFirestore();
    final service = FriendService(firestore: firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: FriendsScreen(uid: uid, displayName: displayName),
        ),
      ),
    );
    await tester.pump();
    return service;
  }

  testWidgets('shows empty states for both tabs with no friendships', (tester) async {
    await pumpFriends(tester, uid: 'u1');

    expect(find.text('フレンドはまだいません'), findsOneWidget);
  });

  testWidgets('shows an accepted friend in the フレンド tab', (tester) async {
    final service = await pumpFriends(tester, uid: 'u1');
    await service.sendRequest('u2', 'Bob', 'u1');
    await service.acceptRequest('u1', 'u2');
    await tester.pump();
    await tester.pump();

    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('shows an incoming pending request with accept/decline on the 招待待ち tab', (
    tester,
  ) async {
    final service = await pumpFriends(tester, uid: 'u1');
    await service.sendRequest('u2', 'Bob', 'u1');
    await tester.pump();

    await tester.tap(find.text('招待待ち'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('申請が届いています'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shows an outgoing pending request with a cancel button on the 招待待ち tab', (
    tester,
  ) async {
    final service = await pumpFriends(tester, uid: 'u1');
    await service.sendRequest('u1', 'Alice', 'u2');
    await tester.pump();

    await tester.tap(find.text('招待待ち'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsNothing);
    expect(find.text('送信済み - 相手の返答待ち'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
  });

  testWidgets('accepting an incoming request moves it into the フレンド tab', (tester) async {
    final service = await pumpFriends(tester, uid: 'u1');
    await service.sendRequest('u2', 'Bob', 'u1');
    await tester.pump();

    await tester.tap(find.text('招待待ち'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('フレンド')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('sending a friend request via the dialog persists it', (tester) async {
    final service = await pumpFriends(tester, uid: 'u1', displayName: 'Alice');

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'u2');
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    final pending = await service.pendingStream('u2').first;
    expect(pending, hasLength(1));
    expect(pending.first.friendUid, 'u1');
  });
}
