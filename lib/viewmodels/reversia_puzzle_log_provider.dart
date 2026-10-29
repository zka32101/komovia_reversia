import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reversia_puzzle_log_service.dart';
import 'reversia_weekly_progress_provider.dart';

final reversiaPuzzleLogServiceProvider = Provider<ReversiaPuzzleLogService>((ref) {
  return ReversiaPuzzleLogService(FirebaseFirestore.instance);
});

/// [uid]の現在の連続解答日数。
final reversiaPuzzleStreakProvider = FutureProvider.family<int, String>((
  ref,
  uid,
) {
  return ref.watch(reversiaPuzzleLogServiceProvider).getStreak(uid);
});

/// (uid, dateKey, correct)を渡してその日の挑戦を記録する。
final recordReversiaPuzzleAttemptProvider = Provider<
    Future<void> Function({
      required String uid,
      required String dateKey,
      required bool correct,
    })>((ref) {
  final service = ref.watch(reversiaPuzzleLogServiceProvider);
  return ({required uid, required dateKey, required correct}) async {
    final wasAlreadySolved = (await service.getLog(uid, dateKey))?.solved ?? false;
    await service.recordAttempt(uid: uid, dateKey: dateKey, correct: correct);
    // 週の目標は「その日最初に解けた瞬間」だけ加算する - 既に解いた日に
    // 再挑戦しても二重に数えない（同じ日の複数回挑戦は`recordAttempt`
    // 側で既に`solved`が`true`のまま保たれる設計と揃える）。
    if (correct && !wasAlreadySolved) {
      try {
        await ref.read(reversiaWeeklyProgressServiceProvider).recordPuzzleSolved(uid: uid);
      } catch (_) {
        // best-effort: パズル記録自体は既に成立している
      }
    }
  };
});
