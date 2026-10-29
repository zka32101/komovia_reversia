import 'package:cloud_firestore/cloud_firestore.dart';

/// フレンド対戦用の招待コード。`ReversiaMatchmakingQueueEntry`/
/// `ReversiaMatchResult`（不特定の相手とのランダムマッチング）とは別の、
/// 「特定の相手を指名して対戦する」ための仕組み — 競合アプリの
/// Piccolo: Othelloなどが採用する、フレンド機能自体を持たない
/// 共有コード方式（アプリ外でコードを伝える前提。ランクには影響しない）。
///
/// `reversia_challenge_codes/{code}`に保存。[guestUid]が入るまでは
/// [status] == 'waiting'、ゲスト側が参加すると'matched'に、
/// [gameId]はその後別の書き込みで付与される（`ReversiaMatchResult`の
/// `gameId`と同じ、マッチ成立→対局作成の2段階パターン）。
class ReversiaChallengeCode {
  final String code;
  final String hostUid;
  final String hostDisplayName;
  final String? guestUid;
  final String? guestDisplayName;
  final String status; // 'waiting', 'matched'
  final String? gameId;
  final DateTime createdAt;

  ReversiaChallengeCode({
    required this.code,
    required this.hostUid,
    required this.hostDisplayName,
    this.guestUid,
    this.guestDisplayName,
    required this.status,
    this.gameId,
    required this.createdAt,
  });

  factory ReversiaChallengeCode.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReversiaChallengeCode(
      code: doc.id,
      hostUid: data['hostUid'] as String? ?? '',
      hostDisplayName: data['hostDisplayName'] as String? ?? 'Player',
      guestUid: data['guestUid'] as String?,
      guestDisplayName: data['guestDisplayName'] as String?,
      status: data['status'] as String? ?? 'waiting',
      gameId: data['gameId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostUid': hostUid,
      'hostDisplayName': hostDisplayName,
      'guestUid': guestUid,
      'guestDisplayName': guestDisplayName,
      'status': status,
      'gameId': gameId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
