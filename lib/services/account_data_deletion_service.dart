import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../src/reversia_weekly_goal.dart';

/// Deletes the Firestore data owned by a user when they delete their
/// account. Same approach as komovia_go's `AccountDataDeletionService`:
/// every step is attempted independently (one rule rejection or network
/// error never leaves the rest behind), the whole thing is idempotent, and
/// the names of failed steps are returned for the caller to report.
///
/// Data shared with other players (PvP games, match results, DMs,
/// tournaments) is intentionally left as-is — the security rules don't
/// allow deleting it anyway (`allow delete: if false`), and the other
/// player's history should not silently change.
class AccountDataDeletionService {
  AccountDataDeletionService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// `reversia_weekly_progress` docs are keyed `{uid}_{weekId}` and the
  /// rules only permit per-document access, so we delete each past week's
  /// id directly instead of querying (deleting a missing doc is a no-op).
  static const weeklyProgressWeeksToDelete = 156; // ~3 years

  Future<List<String>> deleteAllUserData(String uid, {DateTime? now}) async {
    final failures = <String>[];

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
      } catch (_) {
        failures.add(name);
      }
    }

    // Remove this user from each friend's list first, while our own list
    // still tells us who they are.
    await step('friend mirrors', () async {
      final friends =
          await _db.collection('users').doc(uid).collection('friends').get();
      for (final doc in friends.docs) {
        await _db
            .collection('users')
            .doc(doc.id)
            .collection('friends')
            .doc(uid)
            .delete();
      }
    });
    await step(
        'users/$uid/friends',
        () => _deleteCollection(
            _db.collection('users').doc(uid).collection('friends')));
    await step(
        'achievements/$uid/unlocked',
        () => _deleteCollection(
            _db.collection('achievements').doc(uid).collection('unlocked')));
    await step(
        'notifications/$uid/items',
        () => _deleteCollection(
            _db.collection('notifications').doc(uid).collection('items')));
    await step(
        'notifications/$uid/notificationPreferences',
        () => _deleteCollection(_db
            .collection('notifications')
            .doc(uid)
            .collection('notificationPreferences')));
    await step(
        'reversia_puzzle_logs/$uid/days',
        () => _deleteCollection(_db
            .collection('reversia_puzzle_logs')
            .doc(uid)
            .collection('days')));

    await step('leaderboards', () async {
      for (final period in LeaderboardPeriod.values) {
        for (final type in LeaderboardType.values) {
          await _db
              .collection('leaderboards')
              .doc(period.toShortString())
              .collection(type.toShortString())
              .doc(uid)
              .delete();
        }
      }
    });

    await step('reversia_weekly_progress', () async {
      final batch = _db.batch();
      // Noon avoids DST edge cases when stepping back whole weeks.
      final base = now ?? DateTime.now();
      var day = DateTime(base.year, base.month, base.day, 12);
      for (var i = 0; i < weeklyProgressWeeksToDelete; i++) {
        batch.delete(_db
            .collection('reversia_weekly_progress')
            .doc('${uid}_${reversiaWeekId(day)}'));
        day = day.subtract(const Duration(days: 7));
      }
      await batch.commit();
    });

    for (final name in const [
      'reversia_game_stats',
      'reversia_difficulty_stats',
      'reversia_matchmaking_queue',
      'premium_entitlements',
    ]) {
      await step('$name/$uid', () => _db.collection(name).doc(uid).delete());
    }

    // Profile document last, so a retried partial deletion is still
    // identifiable.
    await step('users/$uid', () => _db.collection('users').doc(uid).delete());

    return failures;
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await ref.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
