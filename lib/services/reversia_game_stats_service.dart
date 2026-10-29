import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reversia_game_stats.dart';

/// `ReversiaGameStats`の永続化。
class ReversiaGameStatsService {
  ReversiaGameStatsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _doc(String uid) =>
      _firestore.collection('reversia_game_stats').doc(uid);

  Future<ReversiaGameStats> getStats(String uid) async {
    final doc = await _doc(uid).get();
    if (!doc.exists) return ReversiaGameStats.initial;
    return ReversiaGameStats.fromFirestore(doc.data()!);
  }

  Stream<ReversiaGameStats> watchStats(String uid) {
    return _doc(uid).snapshots().map(
          (doc) => doc.exists
              ? ReversiaGameStats.fromFirestore(doc.data()!)
              : ReversiaGameStats.initial,
        );
  }

  /// 1局の結果を記録する。[won]/[draw]のどちらもfalseなら負けとして
  /// 扱う。トランザクション内で読み取り・更新することで、連勝数の
  /// 計算（直前の連勝数に依存する）が同時更新で壊れないようにする
  /// （実際には1人のプレイヤーのAI対局は同時に進行しないため理論上の
  /// 保険だが、他のサービスの既存の書き込みパターンに合わせている）。
  Future<void> recordGameResult({
    required String uid,
    required bool won,
    bool draw = false,
  }) {
    final ref = _doc(uid);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? ReversiaGameStats.fromFirestore(snapshot.data()!)
          : ReversiaGameStats.initial;

      final newStreak = won ? current.currentWinStreak + 1 : 0;
      final updated = ReversiaGameStats(
        totalGames: current.totalGames + 1,
        wins: current.wins + (won ? 1 : 0),
        losses: current.losses + (!won && !draw ? 1 : 0),
        draws: current.draws + (draw ? 1 : 0),
        currentWinStreak: newStreak,
        longestWinStreak:
            newStreak > current.longestWinStreak ? newStreak : current.longestWinStreak,
      );
      transaction.set(ref, updated.toFirestore());
    });
  }
}
