import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/friend_service.dart';

final friendServiceProvider = Provider<FriendService>((ref) => FriendService());

final friendsStreamProvider = StreamProvider.family<List<Friendship>, String>(
  (ref, uid) => ref.watch(friendServiceProvider).friendsStream(uid),
);

final pendingFriendsStreamProvider =
    StreamProvider.family<List<Friendship>, String>(
  (ref, uid) => ref.watch(friendServiceProvider).pendingStream(uid),
);

final sendFriendRequestProvider = Provider(
  (ref) => (String fromUid, String fromDisplayName, String toUid) => ref
      .read(friendServiceProvider)
      .sendRequest(fromUid, fromDisplayName, toUid),
);

final acceptFriendRequestProvider = Provider(
  (ref) => (String uid, String friendUid) =>
      ref.read(friendServiceProvider).acceptRequest(uid, friendUid),
);

final rejectFriendRequestProvider = Provider(
  (ref) => (String uid, String friendUid) =>
      ref.read(friendServiceProvider).rejectRequest(uid, friendUid),
);

final removeFriendProvider = Provider(
  (ref) => (String uid, String friendUid) =>
      ref.read(friendServiceProvider).removeFriend(uid, friendUid),
);

final blockFriendProvider = Provider(
  (ref) => (String uid, String friendUid) =>
      ref.read(friendServiceProvider).blockFriend(uid, friendUid),
);

final unblockFriendProvider = Provider(
  (ref) => (String uid, String friendUid) =>
      ref.read(friendServiceProvider).unblockFriend(uid, friendUid),
);
