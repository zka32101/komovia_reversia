import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/achievement_service.dart';
import 'leaderboard_provider.dart';

final achievementServiceProvider = Provider<AchievementService>(
  (ref) => AchievementService(leaderboard: ref.watch(leaderboardServiceProvider)),
);

final achievementProgressProvider =
    FutureProvider.family<List<AchievementProgress>, String>((ref, uid) {
  return ref.watch(achievementServiceProvider).getAllProgress(uid);
});

final unlockedAchievementIdsProvider =
    StreamProvider.family<Set<String>, String>((ref, uid) {
  return ref.watch(achievementServiceProvider).unlockedIdsStream(uid);
});

/// 対局勝利・パズル解答などの直後にbest-effortで呼ぶ想定。
final checkAndUnlockAchievementsProvider =
    Provider<Future<void> Function(String uid)>((ref) {
  final service = ref.watch(achievementServiceProvider);
  return (uid) => service.checkAndUnlockAchievements(uid);
});
