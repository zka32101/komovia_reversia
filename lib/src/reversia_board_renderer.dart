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
        ),
      ),
    );
  }

  /// Assumes the board is rendered at a square size equal to [size].width
  /// (as [build] always lays it out via `AspectRatio(aspectRatio: 1)`).
  @override
  Square? squareAt(BoardOffset offset, BoardSize size, ReversiaPosition position) {
    final cell = size.width / ReversiaPosition.boardSize;
    if (cell <= 0) return null;
    final file = (offset.dx / cell).floor();
    final rank = (offset.dy / cell).floor();
    if (file < 0 || file >= ReversiaPosition.boardSize) return null;
    if (rank < 0 || rank >= ReversiaPosition.boardSize) return null;
    return Square(file, rank);
  }
}
