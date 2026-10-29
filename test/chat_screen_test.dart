import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/direct_message_service.dart';
import 'package:komovia_reversia/viewmodels/direct_message_provider.dart';
import 'package:komovia_reversia/views/screens/chat_screen.dart';

void main() {
  Future<DirectMessageService> pumpChat(WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = DirectMessageService(firestore: firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [directMessageServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: ChatScreen(
            currentUid: 'u1',
            currentDisplayName: 'Alice',
            friendUid: 'u2',
            friendDisplayName: 'Bob',
          ),
        ),
      ),
    );
    await tester.pump();
    return service;
  }

  testWidgets('shows an empty state with no messages', (tester) async {
    await pumpChat(tester);

    expect(find.text('まだメッセージはありません'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget); // app bar title
  });

  testWidgets('sending a message persists it and clears the input', (tester) async {
    final service = await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'こんにちは');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('こんにちは'), findsOneWidget);

    final threadId = DirectMessageService.threadIdFor('u1', 'u2');
    final messages = await service.watchMessages(threadId).first;
    expect(messages, hasLength(1));
  });

  testWidgets('opening the screen marks the thread read for the current user', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = DirectMessageService(firestore: firestore);
    await service.sendMessage(
      fromUid: 'u2',
      fromDisplayName: 'Bob',
      toUid: 'u1',
      toDisplayName: 'Alice',
      content: 'こんにちは',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [directMessageServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: ChatScreen(
            currentUid: 'u1',
            currentDisplayName: 'Alice',
            friendUid: 'u2',
            friendDisplayName: 'Bob',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final threads = await service.watchThreadsForUser('u1').first;
    expect(threads.first.unreadCountFor('u1'), 0);
  });

  testWidgets('messages from the current user and the friend render differently aligned', (
    tester,
  ) async {
    final service = await pumpChat(tester);
    await service.sendMessage(
      fromUid: 'u2',
      fromDisplayName: 'Bob',
      toUid: 'u1',
      toDisplayName: 'Alice',
      content: '相手からのメッセージ',
    );
    await tester.pump();
    await tester.pump();

    final align = tester.widget<Align>(
      find.ancestor(of: find.text('相手からのメッセージ'), matching: find.byType(Align)).first,
    );
    expect(align.alignment, Alignment.centerLeft);
  });
}
