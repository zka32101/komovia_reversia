import '../models/reversia_weekly_progress.dart';

/// [date]を含む週（月曜始まり）の識別子。project-015のポイント/バッジ
/// 報酬は含まず、今週の進捗を集計する際のドキュメントキーにのみ使う
/// （`reversiaMoveNotation`等と同じく、日付計算だけの純粋関数）。
String reversiaWeekId(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year.toString().padLeft(4, '0')}-'
      '${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';
}

/// 週替わりの目標。project-015の`weekly_goals_provider.dart`の
/// `WeeklyGoal`の移植漏れ分 - ポイント/バッジ報酬や達成予測
/// （`isAchievableByEndDate`）は無い、固定3種の目標のみの最小構成。
class ReversiaWeeklyGoal {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final int target;
  final int Function(ReversiaWeeklyProgress progress) valueOf;

  const ReversiaWeeklyGoal({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.target,
    required this.valueOf,
  });

  double progressOf(ReversiaWeeklyProgress progress) {
    if (target == 0) return 0;
    return (valueOf(progress) / target).clamp(0, 1).toDouble();
  }

  bool isCompletedBy(ReversiaWeeklyProgress progress) => valueOf(progress) >= target;

  static const all = <ReversiaWeeklyGoal>[
    ReversiaWeeklyGoal(
      id: 'play3',
      emoji: '🎮',
      title: '今週3局プレイ',
      description: 'AI対局・PvP対局を合わせて3局プレイしよう',
      target: 3,
      valueOf: _gamesPlayed,
    ),
    ReversiaWeeklyGoal(
      id: 'win2',
      emoji: '🏆',
      title: '今週2勝',
      description: '今週のうちに2局勝とう',
      target: 2,
      valueOf: _wins,
    ),
    ReversiaWeeklyGoal(
      id: 'puzzle3',
      emoji: '🧩',
      title: '今週パズルを3日解く',
      description: '「今日の1局」を3日分解こう',
      target: 3,
      valueOf: _puzzlesSolved,
    ),
  ];

  static int _gamesPlayed(ReversiaWeeklyProgress p) => p.gamesPlayed;
  static int _wins(ReversiaWeeklyProgress p) => p.wins;
  static int _puzzlesSolved(ReversiaWeeklyProgress p) => p.puzzlesSolved;
}
