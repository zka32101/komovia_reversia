/// AI難易度（1=初級/2=中級/3=上級）ごとの対局数・勝数。
/// `reversia_difficulty_stats/{uid}`に保存。project-015の
/// `difficulty_progression_provider.dart`の移植漏れ分 - 難易度を
/// 上げる/下げるべきかの判定（`reversia_difficulty_recommendation.dart`）
/// に必要な、実際の対局結果の集計のみを持つ。
class ReversiaLevelRecord {
  final int games;
  final int wins;

  const ReversiaLevelRecord({required this.games, required this.wins});

  static const zero = ReversiaLevelRecord(games: 0, wins: 0);

  double get winRate => games == 0 ? 0 : wins / games;
}

class ReversiaDifficultyStats {
  final Map<int, ReversiaLevelRecord> byLevel;

  const ReversiaDifficultyStats(this.byLevel);

  static const initial = ReversiaDifficultyStats({});

  ReversiaLevelRecord statsFor(int level) => byLevel[level] ?? ReversiaLevelRecord.zero;

  Map<String, Object?> toFirestore() => {
        for (final entry in byLevel.entries) ...{
          'level${entry.key}Games': entry.value.games,
          'level${entry.key}Wins': entry.value.wins,
        },
      };

  factory ReversiaDifficultyStats.fromFirestore(Map<String, Object?> json) {
    final byLevel = <int, ReversiaLevelRecord>{};
    for (final level in const [1, 2, 3]) {
      final games = json['level${level}Games'] as int? ?? 0;
      final wins = json['level${level}Wins'] as int? ?? 0;
      if (games > 0 || wins > 0) {
        byLevel[level] = ReversiaLevelRecord(games: games, wins: wins);
      }
    }
    return ReversiaDifficultyStats(byLevel);
  }
}
