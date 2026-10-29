/// 1人のプレイヤーのAI対局の勝敗・連勝記録。`reversia_game_stats/{uid}`
/// に保存。project-015の`engine/statistics.dart`（`GameStatistics`）の
/// 移植漏れ分 - 既存の`LeaderboardEntry`（`gamesPlayed`/`wins`/
/// `winRate`）には引き分け数・連勝数が無く、`komovia_core`の共有モデル
/// を変更すると他のKomoviaシリーズのJSON形状にも影響するため、
/// reversia専用の小さなドキュメントとして別管理する。
class ReversiaGameStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final int currentWinStreak;
  final int longestWinStreak;

  const ReversiaGameStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.currentWinStreak,
    required this.longestWinStreak,
  });

  static const initial = ReversiaGameStats(
    totalGames: 0,
    wins: 0,
    losses: 0,
    draws: 0,
    currentWinStreak: 0,
    longestWinStreak: 0,
  );

  Map<String, Object?> toFirestore() => {
        'totalGames': totalGames,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'currentWinStreak': currentWinStreak,
        'longestWinStreak': longestWinStreak,
      };

  factory ReversiaGameStats.fromFirestore(Map<String, Object?> json) {
    return ReversiaGameStats(
      totalGames: json['totalGames'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      currentWinStreak: json['currentWinStreak'] as int? ?? 0,
      longestWinStreak: json['longestWinStreak'] as int? ?? 0,
    );
  }
}
