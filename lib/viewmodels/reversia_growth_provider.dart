import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../utils/reversia_rating.dart';
import 'achievement_provider.dart';
import 'auth_provider.dart';
import 'leaderboard_provider.dart';
import 'reversia_difficulty_stats_provider.dart';
import 'reversia_game_stats_provider.dart';
import 'reversia_weekly_progress_provider.dart';

/// AI対局終了時にレーティング・対局数・勝数を更新する（komovia_shogiの
/// `updateShogiRatingAfterGameProvider`に相当）。失敗はbest-effortで握り
/// つぶす — ソーシャル機能はサインイン済みでなければ動かないが、対局
/// 自体はサインインなしでも遊べるため、ここで例外を投げると対局終了
/// 処理そのものをブロックしてしまう。
final updateReversiaRatingAfterGameProvider =
    Provider<Future<void> Function(GameResult result, int aiLevel)>((ref) {
  return (result, aiLevel) async {
    if (result.kind == ResultKind.ongoing) return;

    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      final service = ref.read(leaderboardServiceProvider);
      const humanSide = Side.first;
      final entry = await service.getEntry(uid);
      final currentRating = entry?.rating ?? 1200;
      final delta = computeReversiaRatingDelta(
        currentRating: currentRating,
        aiLevel: aiLevel,
        result: result,
        humanSide: humanSide,
      );
      final won = result.kind == ResultKind.win && result.winner == humanSide;
      final isDraw = result.kind == ResultKind.draw;
      await service.incrementStats(
        uid: uid,
        displayName: entry?.displayName ?? 'Player ${uid.substring(0, 6)}',
        ratingDelta: delta,
        gamesDelta: 1,
        winsDelta: won ? 1 : 0,
      );
      await ref.read(reversiaGameStatsServiceProvider).recordGameResult(
            uid: uid,
            won: won,
            draw: isDraw,
          );
      await ref.read(reversiaWeeklyProgressServiceProvider).recordGamePlayed(
            uid: uid,
            won: won,
          );
      await ref.read(reversiaDifficultyStatsServiceProvider).recordGame(
            uid: uid,
            level: aiLevel,
            won: won,
          );
      if (won) {
        await ref.read(checkAndUnlockAchievementsProvider)(uid);
      }
    } catch (_) {
      // best-effort: 対局自体は常に続行できる
    }
  };
});
