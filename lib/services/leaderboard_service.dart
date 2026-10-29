import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// Ranking service, following komovia_shogi's `leaderboard_service.dart`
/// (itself ported from komovia_go): period/type-keyed collections at
/// `leaderboards/{period}/{type}/{uid}`. A single default period/type
/// (all-time/rating) is enough for this first pass — the UI can grow
/// period/type pickers later without a schema change, since the
/// collection path already supports it.
class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> _collection(
    LeaderboardPeriod period,
    LeaderboardType type,
  ) => _firestore
      .collection('leaderboards')
      .doc(period.toShortString())
      .collection(type.toShortString());

  /// Full-overwrite update (e.g. after a profile/rating recalculation).
  Future<void> updateEntry(
    LeaderboardEntry entry, {
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
    LeaderboardType type = LeaderboardType.rating,
  }) {
    return _collection(
      period,
      type,
    ).doc(entry.uid).set(entry.toJson(), SetOptions(merge: true));
  }

  /// Transactional incrementing update, so concurrent game-result writers
  /// (e.g. both players of a PvP game reporting their own result at once)
  /// can't clobber each other.
  Future<void> incrementStats({
    required String uid,
    required String displayName,
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
    LeaderboardType type = LeaderboardType.rating,
    int ratingDelta = 0,
    int gamesDelta = 0,
    int winsDelta = 0,
    int puzzlesDelta = 0,
  }) async {
    final ref = _collection(period, type).doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? LeaderboardEntry.fromJson(snap.data()!)
          : LeaderboardEntry(
              uid: uid,
              displayName: displayName,
              rank: 0,
              rating: 1200,
              gamesPlayed: 0,
              wins: 0,
              winRate: 0,
              puzzlesSolved: 0,
              lastUpdated: DateTime.now(),
            );
      final newGames = current.gamesPlayed + gamesDelta;
      final newWins = current.wins + winsDelta;
      final updated = current.copyWith(
        displayName: displayName,
        rating: current.rating + ratingDelta,
        gamesPlayed: newGames,
        wins: newWins,
        winRate: newGames == 0 ? 0 : newWins / newGames,
        puzzlesSolved: current.puzzlesSolved + puzzlesDelta,
        lastUpdated: DateTime.now(),
      );
      tx.set(ref, updated.toJson());
    });
  }

  Stream<List<LeaderboardEntry>> topEntriesStream({
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
    LeaderboardType type = LeaderboardType.rating,
    int limit = 50,
  }) {
    return _collection(period, type)
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => LeaderboardEntry.fromJson(d.data()))
              .toList(),
        );
  }

  Future<LeaderboardEntry?> getEntry(
    String uid, {
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
    LeaderboardType type = LeaderboardType.rating,
  }) async {
    final doc = await _collection(period, type).doc(uid).get();
    if (!doc.exists) return null;
    return LeaderboardEntry.fromJson(doc.data()!);
  }
}
