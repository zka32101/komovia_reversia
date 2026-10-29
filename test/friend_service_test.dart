import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/friend_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FriendService service;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = FriendService(firestore: firestore);
    await firestore.collection('users').doc('u1').set({'displayName': 'Alice'});
    await firestore.collection('users').doc('u2').set({'displayName': 'Bob'});
  });

  test('sendRequest creates a pending entry on both sides with the sender recorded', () async {
    await service.sendRequest('u1', 'Alice', 'u2');

    final mine = await firestore.collection('users').doc('u1').collection('friends').doc('u2').get();
    final theirs = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();

    expect(mine.data()?['status'], 'pending');
    expect(mine.data()?['requestedBy'], 'u1');
    expect(mine.data()?['displayName'], 'Bob');
    expect(theirs.data()?['status'], 'pending');
    expect(theirs.data()?['requestedBy'], 'u1');
    expect(theirs.data()?['displayName'], 'Alice');
  });

  test('resending a request preserves the original requestedBy', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.sendRequest('u2', 'Bob', 'u1');

    final theirs = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();
    expect(theirs.data()?['requestedBy'], 'u1');
  });

  test('acceptRequest flips both sides to accepted', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');

    final mine = await firestore.collection('users').doc('u1').collection('friends').doc('u2').get();
    final theirs = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();
    expect(mine.data()?['status'], 'accepted');
    expect(theirs.data()?['status'], 'accepted');
  });

  test('acceptRequest is a no-op when there is nothing pending', () async {
    await service.acceptRequest('u2', 'u1');

    final doc = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();
    expect(doc.exists, isFalse);
  });

  test('rejectRequest removes both pending sides and refuses on an accepted friendship', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.rejectRequest('u2', 'u1');

    expect((await firestore.collection('users').doc('u1').collection('friends').doc('u2').get()).exists, isFalse);
    expect((await firestore.collection('users').doc('u2').collection('friends').doc('u1').get()).exists, isFalse);

    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.rejectRequest('u1', 'u2');
    expect((await firestore.collection('users').doc('u1').collection('friends').doc('u2').get()).data()?['status'], 'accepted');
  });

  test('a fresh request can be sent again after rejection', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.rejectRequest('u2', 'u1');
    await service.sendRequest('u1', 'Alice', 'u2');

    final doc = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();
    expect(doc.data()?['status'], 'pending');
  });

  test('friendsStream only returns accepted friendships', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');

    final friends = await service.friendsStream('u1').first;
    expect(friends, hasLength(1));
    expect(friends.first.friendUid, 'u2');
  });

  test('pendingStream only returns pending friendships', () async {
    await service.sendRequest('u1', 'Alice', 'u2');

    final pending = await service.pendingStream('u2').first;
    expect(pending, hasLength(1));
    expect(pending.first.friendUid, 'u1');
  });

  test('blockFriend mirrors the block onto the target unless already independently blocked', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');

    await service.blockFriend('u1', 'u2');

    final mine = await firestore.collection('users').doc('u1').collection('friends').doc('u2').get();
    final theirs = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();
    expect(mine.data()?['status'], 'blocked');
    expect(mine.data()?['blockedBy'], 'u1');
    expect(theirs.data()?['status'], 'blocked');
    expect(theirs.data()?['blockedBy'], 'u1');
  });

  test('blockFriend never clobbers a target that already independently blocked', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u2', 'u1');

    await service.blockFriend('u1', 'u2');

    final theirs = await firestore.collection('users').doc('u2').collection('friends').doc('u1').get();
    expect(theirs.data()?['blockedBy'], 'u2');
  });

  test('unblockFriend undoes its own mirror but not an independent block on the target', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u1', 'u2');

    await service.unblockFriend('u1', 'u2');

    expect((await firestore.collection('users').doc('u1').collection('friends').doc('u2').get()).exists, isFalse);
    expect((await firestore.collection('users').doc('u2').collection('friends').doc('u1').get()).exists, isFalse);
  });

  test('a blocked pair disappears from both accepted-friends lists', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u1', 'u2');

    expect(await service.friendsStream('u1').first, isEmpty);
    expect(await service.friendsStream('u2').first, isEmpty);
  });

  test('removeFriend deletes both sides', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');

    await service.removeFriend('u1', 'u2');

    expect((await firestore.collection('users').doc('u1').collection('friends').doc('u2').get()).exists, isFalse);
    expect((await firestore.collection('users').doc('u2').collection('friends').doc('u1').get()).exists, isFalse);
  });

  test('isBlocked reflects the caller\'s own side only', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u1', 'u2');

    expect(await service.isBlocked('u1', 'u2'), isTrue);
    expect(await service.isBlocked('u2', 'u1'), isTrue);
    expect(await service.isBlocked('u1', 'nonexistent'), isFalse);
  });

  test('blockedStream lists a blocked friend for the blocker', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u1', 'u2');

    final blocked = await service.blockedStream('u1').first;

    expect(blocked, hasLength(1));
    expect(blocked.single.friendUid, 'u2');
    expect(blocked.single.displayName, 'Bob');
  });

  test('blockedStream also lists the other side, since they were blocked too', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u1', 'u2');

    final blocked = await service.blockedStream('u2').first;

    expect(blocked, hasLength(1));
    expect(blocked.single.friendUid, 'u1');
  });

  test('unblockFriend via blockedStream removes the entry from the list', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');
    await service.blockFriend('u1', 'u2');

    await service.unblockFriend('u1', 'u2');

    expect(await service.blockedStream('u1').first, isEmpty);
  });

  test('blockedStream is empty with no blocked relationships', () async {
    await service.sendRequest('u1', 'Alice', 'u2');
    await service.acceptRequest('u2', 'u1');

    expect(await service.blockedStream('u1').first, isEmpty);
  });

  group('searchByDisplayName', () {
    test('finds users whose displayName starts with the query', () async {
      final results = await service.searchByDisplayName('Al', 'u2');
      expect(results, hasLength(1));
      expect(results.single.uid, 'u1');
      expect(results.single.displayName, 'Alice');
    });

    test('excludes the caller even if their own name matches', () async {
      final results = await service.searchByDisplayName('Al', 'u1');
      expect(results, isEmpty);
    });

    test('is case-sensitive (Firestore range queries do not fold case)', () async {
      final results = await service.searchByDisplayName('al', 'u2');
      expect(results, isEmpty);
    });

    test('returns an empty list for an empty query without hitting Firestore', () async {
      final results = await service.searchByDisplayName('   ', 'u2');
      expect(results, isEmpty);
    });

    test('returns an empty list when nothing matches', () async {
      final results = await service.searchByDisplayName('Zzz', 'u2');
      expect(results, isEmpty);
    });
  });
}
