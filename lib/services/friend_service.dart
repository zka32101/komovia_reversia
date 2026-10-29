import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/user_search_result.dart';

/// フレンドCRUD - komovia_shogiの`friend_service.dart`と同じ役割・同じ
/// Firestoreスキーマ（両ユーザーの`users/{uid}/friends`サブコレクション
/// にそれぞれ自分視点のエントリーを持つ非正規化設計、`status`
/// ('pending'/'accepted'/'blocked')、`requestedBy`で受信側/送信側を
/// 区別、`blockedBy`でブロック解除が自分側のブロックしか取り消さない
/// ようにする）。`Friendship`自体はkomovia_coreの共通モデル。
class FriendService {
  FriendService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> _friendsOf(String uid) =>
      _firestore.collection('users').doc(uid).collection('friends');

  Friendship _fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    return Friendship.fromJson(Map<String, Object?>.from(doc.data() ?? {}));
  }

  Future<String> _displayNameOf(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['displayName'] as String?) ?? 'Player';
  }

  /// [fromUid]から[toUid]へフレンド申請を送る（再送含む）。
  Future<void> sendRequest(
    String fromUid,
    String fromDisplayName,
    String toUid,
  ) async {
    final toDisplayName = await _displayNameOf(toUid);
    final now = DateTime.now();

    final existing = await _friendsOf(fromUid).doc(toUid).get();
    final requestedBy =
        (existing.data()?['requestedBy'] as String?) ?? fromUid;

    final senderSide = Friendship(
      uid: fromUid,
      friendUid: toUid,
      displayName: toDisplayName,
      status: 'pending',
      requestedBy: requestedBy,
      addedAt: now,
    );
    final recipientSide = Friendship(
      uid: toUid,
      friendUid: fromUid,
      displayName: fromDisplayName,
      status: 'pending',
      requestedBy: requestedBy,
      addedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(_friendsOf(fromUid).doc(toUid), senderSide.toJson());
    batch.set(_friendsOf(toUid).doc(fromUid), recipientSide.toJson());
    await batch.commit();
  }

  Future<void> acceptRequest(String uid, String friendUid) async {
    final mine = await _friendsOf(uid).doc(friendUid).get();
    if (!mine.exists || mine.data()?['status'] != 'pending') return;
    final batch = _firestore.batch();
    batch.update(_friendsOf(uid).doc(friendUid), {'status': 'accepted'});
    batch.update(_friendsOf(friendUid).doc(uid), {'status': 'accepted'});
    await batch.commit();
  }

  /// まだpendingな申請を両側から削除する（拒否、または送信者本人による
  /// キャンセル）。既にpendingでなければ何もしない。
  Future<void> rejectRequest(String uid, String friendUid) async {
    final mine = await _friendsOf(uid).doc(friendUid).get();
    if (!mine.exists || mine.data()?['status'] != 'pending') return;
    final batch = _firestore.batch();
    batch.delete(_friendsOf(uid).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(uid));
    await batch.commit();
  }

  Future<void> removeFriend(String uid, String friendUid) async {
    final batch = _firestore.batch();
    batch.delete(_friendsOf(uid).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(uid));
    await batch.commit();
  }

  /// [friendUid]をブロックする。相手側のエントリーが既に独立して
  /// ブロック状態になっていない限り、相手側のエントリーにもミラーする。
  Future<void> blockFriend(String uid, String friendUid) async {
    final displayName = await _displayNameOf(friendUid);
    await _friendsOf(uid).doc(friendUid).set({
      ...Friendship(
        uid: uid,
        friendUid: friendUid,
        displayName: displayName,
        status: 'blocked',
        blockedBy: uid,
        addedAt: DateTime.now(),
      ).toJson(),
    }, SetOptions(merge: true));

    final target = await _friendsOf(friendUid).doc(uid).get();
    if (target.exists && target.data()?['status'] != 'blocked') {
      await _friendsOf(friendUid).doc(uid).update({
        'status': 'blocked',
        'blockedBy': uid,
      });
    }
  }

  /// このブロックが自分自身によるものである場合のみ解除する。
  Future<void> unblockFriend(String uid, String friendUid) async {
    final mine = await _friendsOf(uid).doc(friendUid).get();
    if (!mine.exists || mine.data()?['status'] != 'blocked') return;
    await _friendsOf(uid).doc(friendUid).delete();

    final target = await _friendsOf(friendUid).doc(uid).get();
    if (target.exists &&
        target.data()?['status'] == 'blocked' &&
        target.data()?['blockedBy'] == uid) {
      await _friendsOf(friendUid).doc(uid).delete();
    }
  }

  /// [uid]自身の視点で[otherUid]をブロックしているかどうか。
  Future<bool> isBlocked(String uid, String otherUid) async {
    final doc = await _friendsOf(uid).doc(otherUid).get();
    return doc.data()?['status'] == 'blocked';
  }

  Stream<List<Friendship>> friendsStream(String uid) {
    return _friendsOf(uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Stream<List<Friendship>> pendingStream(String uid) {
    return _friendsOf(uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  /// [uid]自身の視点でブロック状態になっている相手一覧（[uid]側の
  /// エントリーが`'blocked'`のもの - 自分がブロックした場合と、相手に
  /// ブロックされた場合の両方を含む）。`unblockFriend`は常に呼び出し元
  /// 自身のエントリーを削除するので、どちらの場合でもここから解除できる
  /// （相手が独立にブロックしていた場合は、相手側のエントリーはそのまま
  /// 残る - `blockedBy`が自分でない時は相手側まで削除しないのが既存の
  /// `unblockFriend`の仕様）。
  Stream<List<Friendship>> blockedStream(String uid) {
    return _friendsOf(uid)
        .where('status', isEqualTo: 'blocked')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  /// 表示名の前方一致で他のユーザーを検索する - project-015の
  /// `player_search_provider.dart`の移植漏れ分で、従来は生のUIDを
  /// 入力させるしかなかったフレンド申請フローを補う。Firestoreは全文
  /// 検索をサポートしないため、`displayName`の単一フィールドレンジ
  /// クエリ（``は非常に大きいUnicodeコードポイントで、事実上の
  /// 「前方一致」を実現する常用テクニック）による前方一致検索のみ。
  /// 大文字小文字は区別する。自分自身は結果から除外する。
  Future<List<UserSearchResult>> searchByDisplayName(
    String query,
    String excludeUid, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: trimmed)
        .where('displayName', isLessThan: '$trimmed')
        .limit(limit)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != excludeUid)
        .map((doc) => UserSearchResult(
              uid: doc.id,
              displayName: (doc.data()['displayName'] as String?) ?? 'Player',
            ))
        .toList();
  }
}
