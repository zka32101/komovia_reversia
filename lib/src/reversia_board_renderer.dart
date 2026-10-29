import 'package:flutter/widgets.dart';
import 'package:komovia_core/komovia_core.dart';

import 'reversia_board_painter.dart';
import 'reversia_board_theme.dart';
import 'reversia_position.dart';

/// Reversia's `BoardRenderer<ReversiaPosition, Widget>`, wrapping
/// [ReversiaBoardPainter] in a square `CustomPaint`. See that painter's
/// doc comment for what's ported vs. dropped from project-015's
/// `game_screen.dart`.
///
/// [theme] is a renderer-level setting (not part of `BoardRenderer.build`'s
/// `komovia_core`-defined signature) rather than a per-call parameter -
/// each screen constructs its own `ReversiaBoardRenderer` once, so this
/// matches how `_renderer`/`_engine` are already held as per-screen fields
/// in `main.dart`/the other game screens.
class ReversiaBoardRenderer implements BoardRenderer<ReversiaPosition, Widget> {
  ReversiaBoardRenderer({this.theme = ReversiaBoardTheme.classic});

  final ReversiaBoardTheme theme;

  @override
  Widget build(
    ReversiaPosition position, {
    Move? lastMove,
    List<Square> hints = const [],
    Square? selected,
    bool flipped = false,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: ReversiaBoardPainter(
          position: position,
          lastMove: lastMove,
          hints: hints,
          selected: selected,
          theme: theme,
          flipped: flipped,
        ),
      ),
    );
  }

  /// Assumes the board is rendered at a square size equal to [size].width
  /// (as [build] always lays it out via `AspectRatio(aspectRatio: 1)`).
  /// [flipped] must match the value passed to [build] for this board, or
  /// taps will resolve to the wrong square.
  @override
  Square? squareAt(
    BoardOffset offset,
    BoardSize size,
    ReversiaPosition position, {
    bool flipped = false,
  }) {
    final boardSize = ReversiaPosition.boardSize;
    final cell = size.width / boardSize;
    if (cell <= 0) return null;
    final displayFile = (offset.dx / cell).floor();
    final displayRank = (offset.dy / cell).floor();
    if (displayFile < 0 || displayFile >= boardSize) return null;
    if (displayRank < 0 || displayRank >= boardSize) return null;
    final file = flipped ? boardSize - 1 - displayFile : displayFile;
    final rank = flipped ? boardSize - 1 - displayRank : displayRank;
    return Square(file, rank);
  }
}
