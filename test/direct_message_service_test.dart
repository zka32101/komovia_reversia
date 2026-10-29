import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/direct_message_service.dart';
import 'package:komovia_reversia/services/friend_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DirectMessageService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DirectMessageService(firestore: firestore);
  });

  test('threadIdFor is the same regardless of argument order', () {
    expect(
      DirectMessageService.threadIdFor('u1', 'u2'),
      DirectMessageService.threadIdFor('u2', 'u1'),
    );
  });

  test('sendMessage persists the thread and message, and increments the recipient unread count', () async {
    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob',
      content: 'こんにちは',
    );

    final threads = await service.watchThreadsForUser('u2').first;
    expect(threads, hasLength(1));
    expect(threads.first.lastMessage, 'こんにちは');
    expect(threads.first.lastSenderUid, 'u1');
    expect(threads.first.unreadCountFor('u2'), 1);
    expect(threads.first.unreadCountFor('u1'), 0);

    final threadId = DirectMessageService.threadIdFor('u1', 'u2');
    final messages = await service.watchMessages(threadId).first;
    expect(messages, hasLength(1));
    expect(messages.first.content, 'こんにちは');
    expect(messages.first.fromUid, 'u1');
  });

  test('a blank message is not sent', () async {
    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob',
      content: '   ',
    );

    expect(await service.watchThreadsForUser('u1').first, isEmpty);
  });

  test('the same thread is reused regardless of who sends first', () async {
    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob',
      content: '1通目',
    );
    await service.sendMessage(
      fromUid: 'u2',
      fromDisplayName: 'Bob',
      toUid: 'u1',
      toDisplayName: 'Alice',
      content: '返信',
    );

    final threadId = DirectMessageService.threadIdFor('u1', 'u2');
    final messages = await service.watchMessages(threadId).first;
    expect(messages, hasLength(2));

    final threads = await service.watchThreadsForUser('u1').first;
    expect(threads, hasLength(1));
    expect(threads.first.lastMessage, '返信');
    expect(threads.first.unreadCountFor('u1'), 1);
    expect(threads.first.unreadCountFor('u2'), 0);
  });

  test('markThreadRead resets only the caller\'s own unread count', () async {
    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob',
      content: 'こんにちは',
    );
    final threadId = DirectMessageService.threadIdFor('u1', 'u2');

    await service.markThreadRead(threadId: threadId, uid: 'u2');

    final threads = await service.watchThreadsForUser('u2').first;
    expect(threads.first.unreadCountFor('u2'), 0);
  });

  test('markThreadRead on a never-started thread is a no-op (does not create one)', () async {
    final threadId = DirectMessageService.threadIdFor('u1', 'u2');
    await service.markThreadRead(threadId: threadId, uid: 'u1');

    expect(await service.watchThreadsForUser('u1').first, isEmpty);
  });

  test('sendMessage refuses when the sender has blocked the recipient', () async {
    final friendService = FriendService(firestore: firestore);
    await firestore.collection('users').doc('u1').set({'displayName': 'Alice'});
    await firestore.collection('users').doc('u2').set({'displayName': 'Bob'});
    await friendService.sendRequest('u1', 'Alice', 'u2');
    await friendService.acceptRequest('u2', 'u1');
    await friendService.blockFriend('u1', 'u2');

    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob',
      content: 'こんにちは',
    );

    expect(await service.watchThreadsForUser('u1').first, isEmpty);
  });

  test('participantNames keeps the recipient\'s existing entry fresh rather than overwriting it with stale data', () async {
    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob (旧名)',
      content: '1通目',
    );
    // u2 sends their own message with their now-current name, which should
    // stick even though u1's next send below still passes the stale cached
    // name it had before.
    await service.sendMessage(
      fromUid: 'u2',
      fromDisplayName: 'Bob (新名)',
      toUid: 'u1',
      toDisplayName: 'Alice',
      content: '返信',
    );
    await service.sendMessage(
      fromUid: 'u1',
      fromDisplayName: 'Alice',
      toUid: 'u2',
      toDisplayName: 'Bob (旧名)',
      content: '2通目',
    );

    final threads = await service.watchThreadsForUser('u1').first;
    expect(threads.first.otherDisplayNameFor('u1'), 'Bob (新名)');
  });
}
