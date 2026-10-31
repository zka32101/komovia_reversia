import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// 2人のプレイヤー間の対局（マッチング成立後の実対局）のスナップショット。
///
/// komovia_shogiの`ShogiPvpGame`と同じ設計判断 - 盤面そのものは保存せず、
/// `ReversiaGame.exportRecord`/`importRecord`が扱う着手レコード文字列
/// (`movesRecord`)だけを保存し、再構成時は初期局面から打ち直す。これは
/// `ReversiaGame.result`が千日手判定（`repetitionLimit`）に局面履歴
/// (`historyKeys`)を必要とするため ---
/// `ReversiaGame.encode(position)`自体は盤面全体を1つの文字列に完全に
/// 可逆化できるが、それだけでは履歴が失われ、正しい終局判定ができない。
///
/// このPRではモデルのみを追加する（実際に着手を適用するサービス層は
/// komovia_shogiの`ShogiPvpGameService`と同等のロジックが必要になり、
/// 別PRの範囲）。
class ReversiaPvpGame {
  final String id;
  final String firstUid;
  final String firstDisplayName;
  final String secondUid;
  final String secondDisplayName;
  final String movesRecord;
  final bool isFirstTurn;
  final int movesCount;
  final String status; // 'active', 'finished'
  final String? winnerUid;
  final String?
      result; // 'resignation', 'victory', 'draw', 'forfeit', null(進行中)
  final String? matchId; // ReversiaMatchResult.idとの紐付け（あれば）
  final String? tournamentId;
  final String? tournamentMatchId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReversiaPvpGame({
    required this.id,
    required this.firstUid,
    required this.firstDisplayName,
    required this.secondUid,
    required this.secondDisplayName,
    this.movesRecord = '',
    required this.isFirstTurn,
    required this.movesCount,
    required this.status,
    this.winnerUid,
    this.result,
    this.matchId,
    this.tournamentId,
    this.tournamentMatchId,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  /// uidがSide.firstなら1、Side.secondなら2、対局者でなければ0。
  int playerColorOf(String uid) {
    if (uid == firstUid) return 1;
    if (uid == secondUid) return 2;
    return 0;
  }

  bool isTurnOf(String uid) {
    final color = playerColorOf(uid);
    if (color == 0) return false;
    return (color == 1) == isFirstTurn;
  }

  /// [uid]が、相手が応答していない（`updatedAt`から[policy]の閾値が
  /// 経過している）ことを理由に放置勝ちを申請できるか。判定本体は
  /// komovia_coreの共有型`AbandonmentForfeitPolicy`に委譲する - 申請
  /// できるのは「待っている側」（手番がまだ来ていない側＝相手が応答して
  /// いない側）のみで、自分自身が応答していない側ではない。
  bool canClaimAbandonmentForfeit(
    String uid, {
    required AbandonmentForfeitPolicy policy,
    DateTime? now,
  }) {
    if (!isActive) return false;
    if (playerColorOf(uid) == 0) return false;
    return policy.canClaim(
      isClaimantsTurn: isTurnOf(uid),
      lastActivityAt: updatedAt ?? createdAt,
      now: now,
    );
  }

  /// 待っている側の[uid]が放置勝ちを申請できるようになるまでの残り時間。
  /// 進行中でない・非対局者・自分の手番のいずれかであれば（そもそも申請
  /// 対象にならないので）null。
  Duration? abandonmentForfeitRemaining(
    String uid, {
    required AbandonmentForfeitPolicy policy,
    DateTime? now,
  }) {
    if (!isActive) return null;
    if (playerColorOf(uid) == 0) return null;
    if (isTurnOf(uid)) return null;
    return policy.remaining(lastActivityAt: updatedAt ?? createdAt, now: now);
  }

  factory ReversiaPvpGame.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReversiaPvpGame(
      id: doc.id,
      firstUid: data['firstUid'] as String? ?? '',
      firstDisplayName: data['firstDisplayName'] as String? ?? 'Player 1',
      secondUid: data['secondUid'] as String? ?? '',
      secondDisplayName: data['secondDisplayName'] as String? ?? 'Player 2',
      movesRecord: data['movesRecord'] as String? ?? '',
      isFirstTurn: data['isFirstTurn'] as bool? ?? true,
      movesCount: data['movesCount'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      winnerUid: data['winnerUid'] as String?,
      result: data['result'] as String?,
      matchId: data['matchId'] as String?,
      tournamentId: data['tournamentId'] as String?,
      tournamentMatchId: data['tournamentMatchId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstUid': firstUid,
      'firstDisplayName': firstDisplayName,
      'secondUid': secondUid,
      'secondDisplayName': secondDisplayName,
      'movesRecord': movesRecord,
      'isFirstTurn': isFirstTurn,
      'movesCount': movesCount,
      'status': status,
      'winnerUid': winnerUid,
      'result': result,
      'matchId': matchId,
      'tournamentId': tournamentId,
      'tournamentMatchId': tournamentMatchId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}
