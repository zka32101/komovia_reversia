import 'package:komovia_core/komovia_core.dart';

/// Whether a [ReversiaPiece] is a normal piece or the king.
///
/// Capturing the opponent's king ends the game immediately (see
/// [ReversiaGame.result]) -- see project-015's `GameState.applyMove`.
enum ReversiaPieceType { normal, king }

/// Which way a normal piece faces. The king has no face (always
/// [ReversiaFace.front]; see [ReversiaPiece.copyWith]) since it never flips.
///
/// Determines how a piece moves: front moves one square orthogonally, back
/// jumps two squares diagonally (ported from project-015's
/// `MoveGenerator.destinationsFor`). A piece flips its face every time it
/// moves without capturing a king (ported from `GameState.applyMove`).
enum ReversiaFace {
  front,
  back;

  ReversiaFace get flipped =>
      this == ReversiaFace.front ? ReversiaFace.back : ReversiaFace.front;
}

/// One piece on a [ReversiaPosition]'s board.
class ReversiaPiece {
  final ReversiaPieceType type;
  final Side owner;
  final ReversiaFace face;

  const ReversiaPiece({
    required this.type,
    required this.owner,
    required this.face,
  });

  ReversiaPiece copyWith({Side? owner, ReversiaFace? face}) => ReversiaPiece(
        type: type,
        owner: owner ?? this.owner,
        face: type == ReversiaPieceType.king
            ? ReversiaFace.front
            : (face ?? this.face),
      );

  @override
  bool operator ==(Object other) =>
      other is ReversiaPiece &&
      other.type == type &&
      other.owner == owner &&
      other.face == face;

  @override
  int get hashCode => Object.hash(type, owner, face);

  @override
  String toString() =>
      '${owner == Side.first ? "A" : "B"}${type == ReversiaPieceType.king ? "K" : (face == ReversiaFace.front ? "f" : "b")}';
}

/// A 6x6 Reversia position: board contents plus whose turn it is.
///
/// [cells] is length-36, row-major (index = `square.rank * boardSize +
/// square.file`); null means empty. Ported from project-015's `Board`
/// (`lib/engine/board.dart`), which stored the grid as `List<List<Piece?>>`
/// indexed `[row][col]` -- flattened here to a single list since
/// `komovia_core.Position` carries no board shape of its own.
///
/// [resignedBy] has no equivalent in project-015 (its engine had no resign
/// concept); it exists only to satisfy `komovia_core`'s `Game` contract,
/// which requires every game to support [ResignMove].
class ReversiaPosition extends Position {
  static const int boardSize = 6;

  final List<ReversiaPiece?> cells;

  @override
  final Side sideToMove;

  final Side? resignedBy;

  ReversiaPosition({
    required List<ReversiaPiece?> cells,
    required this.sideToMove,
    this.resignedBy,
  }) : cells = List.unmodifiable(cells) {
    if (cells.length != boardSize * boardSize) {
      throw ArgumentError(
        'cells must have ${boardSize * boardSize} entries, got ${cells.length}',
      );
    }
  }

  /// The index into [cells] for [square]. Public so `ReversiaGame` can
  /// build a new cell list directly rather than going through [copyWith]/
  /// [cellsWith] for every single-cell change it makes while applying a
  /// move.
  static int indexOf(Square square) => square.rank * boardSize + square.file;

  ReversiaPiece? at(Square square) => cells[indexOf(square)];

  ReversiaPosition copyWith({
    List<ReversiaPiece?>? cells,
    Side? sideToMove,
    Side? resignedBy,
  }) {
    return ReversiaPosition(
      cells: cells ?? this.cells,
      sideToMove: sideToMove ?? this.sideToMove,
      resignedBy: resignedBy ?? this.resignedBy,
    );
  }

  /// Returns a copy of [cells] with the piece at [square] replaced.
  List<ReversiaPiece?> cellsWith(Square square, ReversiaPiece? piece) {
    final updated = List<ReversiaPiece?>.of(cells);
    updated[indexOf(square)] = piece;
    return updated;
  }

  bool hasKing(Side side) => cells.any(
        (p) => p != null && p.owner == side && p.type == ReversiaPieceType.king,
      );

  int pieceCount(Side side) =>
      cells.where((p) => p != null && p.owner == side).length;
}
