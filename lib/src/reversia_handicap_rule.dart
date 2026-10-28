import 'package:komovia_core/komovia_core.dart';

import 'reversia_position.dart';

/// Reversia's piece-handicap rules: remove some of [Side.second]'s
/// (後手/AI側の) back-row normal pieces from the standard initial
/// position. [Side.first] still moves first in every variant, mirroring
/// komovia_shogi's `ShogiHandicapRule` convention (piece handicaps keep
/// the same side moving first; it's go's stone handicaps that flip who
/// moves first, since the stones themselves stand in for Black's usual
/// first move).
///
/// Only row 5 (`ReversiaGame.initialPosition`'s back row for
/// [Side.second], 6 normal front-facing pieces, cols 0-5) is ever
/// touched -- row 4's king and its two flanking normal pieces are never
/// removed, since taking away the king would make the handicapped
/// position an instant loss for [Side.second] rather than merely a
/// material disadvantage.
class ReversiaHandicapRule implements HandicapRule<ReversiaPosition> {
  @override
  final String id;

  @override
  final String label;

  final List<int> removedCols;

  const ReversiaHandicapRule._(this.id, this.label, this.removedCols);

  static const int _backRow = 5;

  /// Removes the two corner pieces of 後手's back row.
  static const two = ReversiaHandicapRule._('two', '二枚落ち', [0, 5]);

  /// Removes four of 後手's back-row pieces, leaving only the two
  /// directly behind the king.
  static const four = ReversiaHandicapRule._('four', '四枚落ち', [0, 1, 4, 5]);

  /// Removes 後手's entire back row, leaving only the king and its two
  /// flanking normal pieces on row 4.
  static const six = ReversiaHandicapRule._('six', '六枚落ち', [0, 1, 2, 3, 4, 5]);

  /// Every handicap, in increasing order of material removed.
  static const all = [two, four, six];

  @override
  ReversiaPosition apply(ReversiaPosition standardInitialPosition) {
    var cells = standardInitialPosition.cells;
    for (final col in removedCols) {
      final square = Square(col, _backRow);
      cells = _cellsWith(cells, square, null);
    }
    return standardInitialPosition.copyWith(cells: cells);
  }

  static List<ReversiaPiece?> _cellsWith(
    List<ReversiaPiece?> cells,
    Square square,
    ReversiaPiece? piece,
  ) {
    final updated = List<ReversiaPiece?>.of(cells);
    updated[ReversiaPosition.indexOf(square)] = piece;
    return updated;
  }
}
