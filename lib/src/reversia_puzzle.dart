import 'package:komovia_core/komovia_core.dart';

import 'reversia_position.dart';

/// A fixed rotation of hand-authored "today's puzzle" positions, each
/// solved by a single move that captures the opponent's king. Ported
/// from project-015's `lib/engine/puzzle.dart`.
///
/// Coordinates there were `Square(row, col)`; `komovia_core.Square` is
/// `Square(file, rank)` (file = column, rank = row) -- every square below
/// is the original's column/row swapped, not a fresh authoring.
///
/// Each puzzle MUST have exactly one *winning* move among
/// `position.sideToMove`'s legal moves -- not exactly one legal move
/// overall (a single piece typically has several non-winning
/// destinations too; see [_parkedFirstKing] below) -- verified by
/// `test/reversia_puzzle_test.dart` rather than by eyeballing (ported
/// house rule: data correctness is checked by script, never by
/// inspection alone).
///
/// project-015's puzzles only ever placed the pieces the puzzle actually
/// needs, since its `Board`/`Move` types carry no result/turn logic of
/// their own -- a puzzle was solved by directly checking whether the
/// chosen move's destination held the opponent's king, not by asking a
/// `GameState` whether the game had ended. `ReversiaGame.result`, by
/// contrast, treats a *missing* king for the side to move as that side
/// having already lost (see `ReversiaGame.result`'s checkmate check) --
/// true for any position reachable from a real game, but not for these
/// hand-built ones. Puzzles that didn't already involve a first-side
/// king (every one but `king-strike`) get a harmless one parked in an
/// empty corner, just to keep the position well-formed under that rule;
/// it's placed far enough from every puzzle's pieces to add only
/// non-winning moves of its own.
final List<Puzzle<ReversiaPosition>> dailyReversiaPuzzles = [
  Puzzle<ReversiaPosition>(
    id: 'orthogonal-front',
    gameId: 'reversia',
    metadata: const {'difficultyLabel': 'かんたん'},
    position: _position(sideToMove: Side.first, pieces: [
      (const Square(2, 2),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front)),
      (const Square(3, 2),
          const ReversiaPiece(type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front)),
      _parkedFirstKing,
    ]),
    solution: const [BoardMove(from: Square(2, 2), to: Square(3, 2))],
  ),
  Puzzle<ReversiaPosition>(
    id: 'diagonal-back',
    gameId: 'reversia',
    metadata: const {'difficultyLabel': 'ふつう'},
    position: _position(sideToMove: Side.first, pieces: [
      (const Square(1, 1),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.back)),
      (const Square(3, 3),
          const ReversiaPiece(type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front)),
      // Decoy: a non-winning move must exist so the puzzle isn't a forced single legal move.
      (const Square(0, 5),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front)),
      _parkedFirstKing,
    ]),
    solution: const [BoardMove(from: Square(1, 1), to: Square(3, 3))],
  ),
  Puzzle<ReversiaPosition>(
    id: 'king-strike',
    gameId: 'reversia',
    metadata: const {'difficultyLabel': 'ふつう'},
    position: _position(sideToMove: Side.first, pieces: [
      (const Square(4, 4),
          const ReversiaPiece(type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front)),
      (const Square(5, 4),
          const ReversiaPiece(type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front)),
      (const Square(0, 0),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front)),
    ]),
    solution: const [BoardMove(from: Square(4, 4), to: Square(5, 4))],
  ),
  Puzzle<ReversiaPosition>(
    id: 'diagonal-jump-block',
    gameId: 'reversia',
    metadata: const {'difficultyLabel': 'むずかしい'},
    position: _position(sideToMove: Side.first, pieces: [
      (const Square(0, 0),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.back)),
      (const Square(2, 2),
          const ReversiaPiece(type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front)),
      // Another first-side piece one square off the direct path -- a tempting but wrong move.
      (const Square(1, 0),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front)),
      _parkedFirstKing,
    ]),
    solution: const [BoardMove(from: Square(0, 0), to: Square(2, 2))],
  ),
  Puzzle<ReversiaPosition>(
    id: 'orthogonal-far-side',
    gameId: 'reversia',
    metadata: const {'difficultyLabel': 'かんたん'},
    position: _position(sideToMove: Side.first, pieces: [
      (const Square(2, 5),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front)),
      (const Square(3, 5),
          const ReversiaPiece(type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front)),
      (const Square(5, 0),
          const ReversiaPiece(type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.back)),
      _parkedFirstKing,
    ]),
    solution: const [BoardMove(from: Square(2, 5), to: Square(3, 5))],
  ),
];

/// A first-side king parked at an empty corner, far from every puzzle's
/// pieces -- see [dailyReversiaPuzzles]'s doc comment.
const (Square, ReversiaPiece) _parkedFirstKing = (
  Square(5, 5),
  ReversiaPiece(type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front),
);

ReversiaPosition _position({
  required Side sideToMove,
  required List<(Square, ReversiaPiece)> pieces,
}) {
  final cells = List<ReversiaPiece?>.filled(
    ReversiaPosition.boardSize * ReversiaPosition.boardSize,
    null,
  );
  for (final (square, piece) in pieces) {
    cells[ReversiaPosition.indexOf(square)] = piece;
  }
  return ReversiaPosition(cells: cells, sideToMove: sideToMove);
}

/// Deterministic "Wordle-style" daily selection: every player sees the
/// same puzzle on the same calendar date.
Puzzle<ReversiaPosition> reversiaPuzzleForDate(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  final index = dayOfYear % dailyReversiaPuzzles.length;
  return dailyReversiaPuzzles[index];
}

String formatReversiaPuzzleDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
