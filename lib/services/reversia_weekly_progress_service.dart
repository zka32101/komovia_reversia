import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reversia_weekly_progress.dart';
import '../src/reversia_weekly_goal.dart';

/// 今週の進捗（対局数・勝数・パズル解答数）の記録・購読。
/// `ReversiaGameStatsService`と同じ構造だが、週替わりで自動的に0から
/// 始まる（ドキュメントキーに週の月曜日を含むため）。
class ReversiaWeeklyProgressService {
  ReversiaWeeklyProgressService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _doc(String uid, DateTime now) {
    final weekId = reversiaWeekId(now);
    return _firestore.collection('reversia_weekly_progress').doc('${uid}_$weekId');
  }

  Future<ReversiaWeeklyProgress> getProgress(String uid, {DateTime? now}) async {
    final snapshot = await _doc(uid, now ?? DateTime.now()).get();
    if (!snapshot.exists) return ReversiaWeeklyProgress.initial;
    return ReversiaWeeklyProgress.fromFirestore(snapshot.data()!);
  }

  Stream<ReversiaWeeklyProgress> watchProgress(String uid, {DateTime? now}) {
    return _doc(uid, now ?? DateTime.now()).snapshots().map((snapshot) {
      if (!snapshot.exists) return ReversiaWeeklyProgress.initial;
      return ReversiaWeeklyProgress.fromFirestore(snapshot.data()!);
    });
  }

  Future<void> recordGamePlayed({required String uid, required bool won, DateTime? now}) {
    final ref = _doc(uid, now ?? DateTime.now());
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? ReversiaWeeklyProgress.fromFirestore(snapshot.data()!)
          : ReversiaWeeklyProgress.initial;
      final updated = ReversiaWeeklyProgress(
        gamesPlayed: current.gamesPlayed + 1,
        wins: current.wins + (won ? 1 : 0),
        puzzlesSolved: current.puzzlesSolved,
      );
      transaction.set(ref, updated.toFirestore());
    });
  }

  Future<void> recordPuzzleSolved({required String uid, DateTime? now}) {
    final ref = _doc(uid, now ?? DateTime.now());
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists
          ? ReversiaWeeklyProgress.fromFirestore(snapshot.data()!)
          : ReversiaWeeklyProgress.initial;
      final updated = ReversiaWeeklyProgress(
        gamesPlayed: current.gamesPlayed,
        wins: current.wins,
        puzzlesSolved: current.puzzlesSolved + 1,
      );
      transaction.set(ref, updated.toFirestore());
    });
  }
}
