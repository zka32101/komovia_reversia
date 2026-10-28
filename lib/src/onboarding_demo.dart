import 'package:komovia_core/komovia_core.dart';

import 'reversia_position.dart';

/// A tiny hand-built position for the onboarding screen's interactive
/// "capture a piece" step: 先手の表向きの駒が、すぐ上の後手の駒を直交1マス
/// 移動で取れるだけの、実戦とは無関係の最小構成。
///
/// [ReversiaGame.result] treats "キング不在"として即負けと判定するため
/// （komovia_shogiのonboarding_demo.dartには無い制約 - Reversia独自の
/// ルール）、両者にキングを1枚ずつ、捕獲には関与しない隅に置いている
/// （README/`ReversiaPuzzle`のドキュメントコメントが既に説明している、
/// 名局ライブラリ側でも必要になった同じ回避）。
ReversiaPosition onboardingDemoPosition() {
  final cells = List<ReversiaPiece?>.filled(
    ReversiaPosition.boardSize * ReversiaPosition.boardSize,
    null,
  );
  void place(int file, int rank, ReversiaPiece piece) {
    cells[ReversiaPosition.indexOf(Square(file, rank))] = piece;
  }

  place(0, 0, const ReversiaPiece(
    type: ReversiaPieceType.king,
    owner: Side.first,
    face: ReversiaFace.front,
  ));
  place(5, 5, const ReversiaPiece(
    type: ReversiaPieceType.king,
    owner: Side.second,
    face: ReversiaFace.front,
  ));
  place(2, 3, const ReversiaPiece(
    type: ReversiaPieceType.normal,
    owner: Side.first,
    face: ReversiaFace.front,
  ));
  place(2, 2, const ReversiaPiece(
    type: ReversiaPieceType.normal,
    owner: Side.second,
    face: ReversiaFace.front,
  ));

  return ReversiaPosition(cells: cells, sideToMove: Side.first);
}

/// The one legal move in [onboardingDemoPosition] that actually captures:
/// 先手の表向きの駒がすぐ上（rank-1方向）の後手の駒へ移動する。
const onboardingDemoCaptureMove = BoardMove(
  from: Square(2, 3),
  to: Square(2, 2),
);
