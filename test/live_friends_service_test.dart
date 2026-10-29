import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/friend_service.dart';
import 'package:komovia_reversia/services/live_friends_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FriendService friendService;
  late ReversiaPvpGameService pvpGameService;
  late LiveFriendsService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    friendService = FriendService(firestore: firestore);
    pvpGameService = ReversiaPvpGameService(firestore);
    service = LiveFriendsService(
      friendService: friendService,
      pvpGameService: pvpGameService,
    );
  });

  Future<void> seedUser(String uid, String displayName) async {
    await firestore.collection('users').doc(uid).set({'displayName': displayName});
  }

  test('returns no activity for an uid with no friends', () async {
    await seedUser('u1', 'Alice');

    final activities = await service.getLiveFriends('u1');

    expect(activities, isEmpty);
  });

  test('skips an accepted friend with no active game', () async {
    await seedUser('u1', 'Alice');
    await seedUser('u2', 'Bob');
    await friendService.sendRequest('u1', 'Alice', 'u2');
    await friendService.acceptRequest('u2', 'u1');

    final activities = await service.getLiveFriends('u1');

    expect(activities, isEmpty);
  });

  test('includes a friend who currently has an active PvP game', () async {
    await seedUser('u1', 'Alice');
    await seedUser('u2', 'Bob');
    await friendService.sendRequest('u1', 'Alice', 'u2');
    await friendService.acceptRequest('u2', 'u1');
    final game = await pvpGameService.createGame(
      firstUid: 'u2',
      firstDisplayName: 'Bob',
      secondUid: 'u3',
      secondDisplayName: 'Carol',
    );

    final activities = await service.getLiveFriends('u1');

    expect(activities, hasLength(1));
    expect(activities.single.friendUid, 'u2');
    expect(activities.single.friendDisplayName, 'Bob');
    expect(activities.single.game.id, game.id);
  });

  test('excludes a finished game', () async {
    await seedUser('u1', 'Alice');
    await seedUser('u2', 'Bob');
    await friendService.sendRequest('u1', 'Alice', 'u2');
    await friendService.acceptRequest('u2', 'u1');
    final game = await pvpGameService.createGame(
      firstUid: 'u2',
      firstDisplayName: 'Bob',
      secondUid: 'u3',
      secondDisplayName: 'Carol',
    );
    await pvpGameService.resign(gameId: game.id, uid: 'u2');

    final activities = await service.getLiveFriends('u1');

    expect(activities, isEmpty);
  });

  test('excludes a blocked friend relationship', () async {
    await seedUser('u1', 'Alice');
    await seedUser('u2', 'Bob');
    await friendService.sendRequest('u1', 'Alice', 'u2');
    await friendService.acceptRequest('u2', 'u1');
    await friendService.blockFriend('u1', 'u2');
    await pvpGameService.createGame(
      firstUid: 'u2',
      firstDisplayName: 'Bob',
      secondUid: 'u3',
      secondDisplayName: 'Carol',
    );

    final activities = await service.getLiveFriends('u1');

    expect(activities, isEmpty);
  });
}
