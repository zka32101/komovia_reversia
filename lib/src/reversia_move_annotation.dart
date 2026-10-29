/// 対局振り返り画面でユーザーが自分の着手につけるタグ・メモ。
/// project-015の`replay_study_provider.dart`の`MoveTag`/`MoveAnnotation`の
/// 移植漏れ分 - ただし元の`StudiedGame`（ブックマーク・学習セッション
/// 時間計測・永続化）は含まない。これらを持たせるには保存済み対局に
/// 安定したgameIdを[ReversiaGameReviewScreen]まで通す改修が必要（AI対局
/// は`saveInProgressGame`で'local'固定のgameIdしか使っておらず、PvP対局
/// の呼び出し元も実際のgameIdを渡していない）ため、永続化は別スコープ
/// として残し、今回は「振り返り中にその場でタグ・メモを付けられる」
/// 最小構成（画面を閉じると消える、セッション内のみの注釈）とした。
enum ReversiaMoveTag {
  brilliant('会心の一手', '💎'),
  good('良い手', '👍'),
  mistake('疑問手', '❓'),
  blunder('悪手', '❌'),
  critical('重要局面', '🔑');

  final String label;
  final String emoji;

  const ReversiaMoveTag(this.label, this.emoji);
}

/// 1手に対するタグ・メモ。両方が空なら実質「注釈なし」。
class ReversiaMoveAnnotation {
  final ReversiaMoveTag? tag;
  final String note;

  const ReversiaMoveAnnotation({this.tag, this.note = ''});

  bool get isEmpty => tag == null && note.trim().isEmpty;
}
