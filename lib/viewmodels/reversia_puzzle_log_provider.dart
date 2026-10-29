import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reversia_puzzle_log_service.dart';

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
  return ({required uid, required dateKey, required correct}) {
    return service.recordAttempt(uid: uid, dateKey: dateKey, correct: correct);
  };
});
