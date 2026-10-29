import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';

/// 1対1のフレンド間メッセージング - komovia_chessの
/// `direct_message_service.dart`と同じ役割・同じFirestoreスキーマ
/// （komovia_coreの共通モデル`MessageThread`/`DirectMessage`を使用）。
/// `participantUids`は[threadIdFor]と同じソート順で常に書く必要がある
/// - そうしないと後から返信する側の書き込みが
/// `request.resource.data.participantUids == resource.data.participantUids`
/// を要求するFirestoreルールに拒否される（komovia_chessの実装コメント
/// 参照、同じ既知のバグクラスを踏まないよう最初からソート順で書く）。
///
/// reversiaの他のサービス（`FriendService`/`NotificationService`）と同じ
/// 変換方針に揃え、Firestoreの`Timestamp`ではなく`DateTime.
/// toIso8601String()`をそのまま保存する（`MessageThread`/`DirectMessage`
/// の`fromJson`は元々`DateTime.parse`前提のISO8601文字列を読む設計の
/// ため）。
///
/// デプロイ時の注意: [watchThreadsForUser]の
/// `participantUids array-contains` + `lastMessageAt`降順クエリは本番
/// Firestoreでは複合インデックスが必要（このリポジトリには
/// `firestore.indexes.json`/`firebase.json`自体がまだ存在しないため、
/// ここにコメントで記録するのみ）。
class DirectMessageService {
  DirectMessageService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> get _threads =>
      _firestore.collection('message_threads');

  MessageThread _threadFromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    return MessageThread.fromJson({...(doc.data() ?? {}), 'id': doc.id});
  }

  DirectMessage _messageFromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    return DirectMessage.fromJson({...(doc.data() ?? {}), 'id': doc.id});
  }

  /// 2者のuidをソートして連結した決定的なthreadId。どちらが先に送信して
  /// もスレッドが重複して作られない。
  static String threadIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    // FriendService.blockFriendは双方のエントリーへブロックをミラーする
    // ので、送信者自身の（読み取り可能な）エントリーだけ確認すれば
    // どちらの側からのブロックでも検知できる。
    final relationship = await _firestore
        .collection('users')
        .doc(fromUid)
        .collection('friends')
        .doc(toUid)
        .get();
    if (relationship.data()?['status'] == 'blocked') {
      debugPrint('sendMessage refused: $fromUid/$toUid have a blocked relationship');
      return;
    }

    final threadId = threadIdFor(fromUid, toUid);
    final threadRef = _threads.doc(threadId);
    final messageRef = threadRef.collection('messages').doc();
    final now = DateTime.now();
    final participantUids = [fromUid, toUid]..sort();

    // トランザクションにする理由 - 送信者自身の`participantNames`エント
    // リーは毎送信で最新化する必要があるが、受信者のエントリーをキャッシ
    // ュされた古い名前で上書きしないためには、スレッドの現在の
    // `participantNames`を先に読む必要がある。また、新規スレッドの
    // 最初のメッセージが先に書かれてしまうと、`messages/{messageId}`の
    // 作成ルールが参照する`message_threads/{threadId}`がまだ存在せず
    // 拒否されるため、スレッド本体を先に書く。
    await _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(threadRef);
      final existingNames =
          (existingSnapshot.data()?['participantNames'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {};

      transaction.set(
        threadRef,
        {
          'participantUids': participantUids,
          'participantNames': {
            ...existingNames,
            fromUid: fromDisplayName,
            if (!existingNames.containsKey(toUid)) toUid: toDisplayName,
          },
          'lastMessage': trimmed,
          'lastMessageAt': now.toIso8601String(),
          'lastSenderUid': fromUid,
          'unreadCount.$toUid': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      transaction.set(messageRef, {
        'fromUid': fromUid,
        'content': trimmed,
        'sentAt': now.toIso8601String(),
      });
    });
  }

  Stream<List<MessageThread>> watchThreadsForUser(String uid) {
    return _threads
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_threadFromDoc).toList());
  }

  Stream<List<DirectMessage>> watchMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_messageFromDoc).toList());
  }

  /// [uid]がこのスレッドを開いた際に未読数をリセットする。一度もメッセ
  /// ージを送っていない相手を開いた場合でも呼ばれるため、スレッドがまだ
  /// 存在しないケースは何もせず戻る（merge書き込みすると、メッセージが
  /// 無いのに空のスレッドが作られ、受信箱に空の会話が表示されてしまう）。
  Future<void> markThreadRead({required String threadId, required String uid}) async {
    final ref = _threads.doc(threadId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    await ref.update({'unreadCount.$uid': 0});
  }
}
