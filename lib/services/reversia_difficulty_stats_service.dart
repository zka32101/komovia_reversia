import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reversia_difficulty_stats.dart';

/// AI難易度ごとの対局数・勝数の記録・購読。`ReversiaGameStatsService`と
/// 同じ構造。
class ReversiaDifficultyStatsService {
  ReversiaDifficultyStatsService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _doc(String uid) =>
      _firestore.collection('reversia_difficulty_stats').doc(uid);

  Future<ReversiaDifficultyStats> getStats(String uid) async {
    final snapshot = await _doc(uid).get();
    if (!snapshot.exists) return ReversiaDifficultyStats.initial;
    return ReversiaDifficultyStats.fromFirestore(snapshot.data()!);
  }

  Stream<ReversiaDifficultyStats> watchStats(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return ReversiaDifficultyStats.initial;
      return ReversiaDifficultyStats.fromFirestore(snapshot.data()!);
    });
  }

  Future<void> recordGame({
    required String uid,
    required int level,
    required bool won,
  }) {
    final ref = _doc(uid);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? ReversiaDifficultyStats.fromFirestore(snapshot.data()!)
          : ReversiaDifficultyStats.initial;
      final record = current.statsFor(level);
      final updated = ReversiaDifficultyStats({
        ...current.byLevel,
        level: ReversiaLevelRecord(
          games: record.games + 1,
          wins: record.wins + (won ? 1 : 0),
        ),
      });
      transaction.set(ref, updated.toFirestore());
    });
  }
}
