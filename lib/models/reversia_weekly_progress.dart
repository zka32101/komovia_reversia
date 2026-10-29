/// 1人のプレイヤーの、ある週の進捗。`reversia_weekly_progress/{uid}_{weekId}`
/// に保存。project-015の`weekly_goals_provider.dart`（`WeeklyGoal`）の
/// 移植漏れ分 - ただし元のポイント/バッジ報酬やプログレス予測
/// （`isAchievableByEndDate`）は含まず、今週の実績カウンターのみ
/// 保持する最小構成。`weekId`自体はドキュメントには含めない
/// （ドキュメントIDの一部としてのみ使う）。
class ReversiaWeeklyProgress {
  final int gamesPlayed;
  final int wins;
  final int puzzlesSolved;

  const ReversiaWeeklyProgress({
    required this.gamesPlayed,
    required this.wins,
    required this.puzzlesSolved,
  });

  static const initial = ReversiaWeeklyProgress(
    gamesPlayed: 0,
    wins: 0,
    puzzlesSolved: 0,
  );

  Map<String, Object?> toFirestore() => {
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'puzzlesSolved': puzzlesSolved,
      };

  factory ReversiaWeeklyProgress.fromFirestore(Map<String, Object?> json) {
    return ReversiaWeeklyProgress(
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      puzzlesSolved: json['puzzlesSolved'] as int? ?? 0,
    );
  }
}
