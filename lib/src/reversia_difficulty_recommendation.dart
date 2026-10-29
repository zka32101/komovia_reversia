import '../models/reversia_difficulty_stats.dart';

/// 現在の難易度を変えるべきかの提案。project-015の
/// `difficulty_progression_provider.dart`の`DifficultyTier`/
/// `ProgressionData`の移植漏れ分だが、元のポイント・バッジ要素は含まず、
/// 実際の勝率のみに基づく最小構成とした。
enum ReversiaDifficultyAdvice {
  /// サンプル数がまだ少ない、または勝率が妥当な範囲にある。
  none,

  /// 勝率が高く、1つ上の難易度を試す余地がある。
  moveUp,

  /// 勝率が低く、1つ下の難易度に下げることを勧める。
  moveDown,
}

/// [currentLevel]（1=初級/2=中級/3=上級）での[stats]から難易度変更の
/// 提案を返す純粋関数。最善を尽くした判定基準で、確定的な正解がある
/// わけではない - [minGames]未満のサンプルでは`none`を返す（まだ判断
/// するには対局数が足りない）。既に最高/最低難易度であればそれ以上
/// 上げる/下げる提案はしない。
ReversiaDifficultyAdvice recommendDifficultyChange({
  required int currentLevel,
  required ReversiaDifficultyStats stats,
  int minGames = 5,
  double moveUpThreshold = 0.7,
  double moveDownThreshold = 0.3,
}) {
  final record = stats.statsFor(currentLevel);
  if (record.games < minGames) return ReversiaDifficultyAdvice.none;

  if (record.winRate >= moveUpThreshold && currentLevel < 3) {
    return ReversiaDifficultyAdvice.moveUp;
  }
  if (record.winRate <= moveDownThreshold && currentLevel > 1) {
    return ReversiaDifficultyAdvice.moveDown;
  }
  return ReversiaDifficultyAdvice.none;
}

const _levelLabels = {1: '初級', 2: '中級', 3: '上級'};

/// [advice]のユーザー向け提案文。`ReversiaDifficultyAdvice.none`では
/// null。
String? reversiaDifficultyAdviceMessage(
  ReversiaDifficultyAdvice advice,
  int currentLevel,
) {
  switch (advice) {
    case ReversiaDifficultyAdvice.none:
      return null;
    case ReversiaDifficultyAdvice.moveUp:
      return '${_levelLabels[currentLevel]}での勝率が高いようです。'
          '${_levelLabels[currentLevel + 1]}に挑戦してみませんか？';
    case ReversiaDifficultyAdvice.moveDown:
      return '${_levelLabels[currentLevel]}が少し難しいようです。'
          '${_levelLabels[currentLevel - 1]}を試してみるのもおすすめです。';
  }
}
