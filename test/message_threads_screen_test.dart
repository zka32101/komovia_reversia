import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/direct_message_service.dart';
import 'package:komovia_reversia/viewmodels/direct_message_provider.dart';
import 'package:komovia_reversia/views/screens/chat_screen.dart';
import 'package:komovia_reversia/views/screens/message_threads_screen.dart';

void main() {
  Future<DirectMessageService> pumpThreads(
    WidgetTester tester, {
    String uid = 'u1',
  }) async {
    final firestore = FakeFirebaseFirestore();
    final service = DirectMessageService(firestore: firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [directMessageServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: MessageThreadsScreen(uid: uid, displayName: 'Alice'),
        ),
      ),
    );
    await tester.pump();
    return service;
  }

  testWidgets('shows an empty state with no conversations', (tester) async {
    await pumpThreads(tester);

    expect(find.text('まだ会話はありません'), findsOneWidget);
  });

  testWidgets('lists a thread with the other participant\'s name, last message, and unread badge', (
    tester,
  ) async {
    final service = await pumpThreads(tester);
    await service.sendMessage(
      fromUid: 'u2',
      fromDisplayName: 'Bob',
      toUid: 'u1',
      toDisplayName: 'Alice',
      content: 'こんにちは',
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('こんにちは'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping a thread opens ChatScreen for that friend', (tester) async {
    final service = await pumpThreads(tester);
    await service.sendMessage(
      fromUid: 'u2',
      fromDisplayName: 'Bob',
      toUid: 'u1',
      toDisplayName: 'Alice',
      content: 'こんにちは',
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Bob'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chatScreen.friendUid, 'u2');
    expect(chatScreen.friendDisplayName, 'Bob');
  });
}
