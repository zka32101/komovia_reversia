import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/user_search_result.dart';
import '../services/friend_service.dart';
import 'notification_provider.dart';

final friendServiceProvider = Provider<FriendService>((ref) => FriendService());

final friendsStreamProvider = StreamProvider.family<List<Friendship>, String>(
  (ref, uid) => ref.watch(friendServiceProvider).friendsStream(uid),
);

final pendingFriendsStreamProvider =
    StreamProvider.family<List<Friendship>, String>(
  (ref, uid) => ref.watch(friendServiceProvider).pendingStream(uid),
);

final blockedFriendsStreamProvider =
    StreamProvider.family<List<Friendship>, String>(
  (ref, uid) => ref.watch(friendServiceProvider).blockedStream(uid),
);

/// 送信成功時、受信者へ`friend_request`通知を送る（komovia_goの
/// `addFriendProvider`と同じ役割）。通知の送信に失敗しても申請自体は
/// 成立しているため、best-effortで握りつぶす。
final sendFriendRequestProvider = Provider(
  (ref) => (String fromUid, String fromDisplayName, String toUid) async {
    await ref.read(friendServiceProvider).sendRequest(fromUid, fromDisplayName, toUid);
    try {
      await ref.read(notificationServiceProvider).send(
            uid: toUid,
            title: '$fromDisplayNameさんからフレンド申請が届きました',
            body: '「フレンド」→「招待待ち」タブで確認できます',
            type: 'friend_request',
          );
    } catch (_) {
      // best-effort: 申請自体は既に成立している
    }
  },
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

/// 表示名の前方一致検索。クエリ文字列ごとの単発呼び出しのため
/// `Provider.family`ではなく、呼び出し側（検索ダイアログ）が結果を
/// 自前の状態として保持する単純なアクションにしている。
final searchUsersByDisplayNameProvider =
    Provider<Future<List<UserSearchResult>> Function(String, String)>(
  (ref) => (query, excludeUid) =>
      ref.read(friendServiceProvider).searchByDisplayName(query, excludeUid),
);
