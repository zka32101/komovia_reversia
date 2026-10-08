import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import 'reversia_position.dart';

/// Paints a [ReversiaPosition] onto a square canvas. Ported from
/// project-015's `game_screen.dart` (`_Board`/`_BoardCell`/`_PieceCircle`),
/// as a self-contained `CustomPainter` instead -- the original drew each
/// square as a `GridView` cell styled with a wood-texture asset image
/// this new package doesn't have, and animated piece flips/captures with
/// `AnimationController`s that depend on `State`, which a stateless
/// `BoardRenderer.build` call has no way to drive. Static highlighting
/// (last move, hints, selection) is kept; the flip animation, capture
/// particle burst, and king-danger pulse are dropped for this stage --
/// they're presentation polish a later pass can add back as a stateful
/// wrapper around this painter, not part of what makes the board correct.
///
/// One finding ported faithfully even though it looks like it should be
/// wrong: a piece's color here is keyed on its *face* (front/back), not
/// on which side owns it -- matching `_PieceCircle`'s
/// `theme.frontPieceColor`/`backPieceColor` exactly. Ownership is instead
/// shown via a highlight ring on whichever side's pieces match
/// `position.sideToMove` (`_BoardCell.isCurrentTurnPiece`'s equivalent).
class ReversiaBoardPainter extends CustomPainter {
  final ReversiaPosition position;
  final Move? lastMove;
  final List<Square> hints;
  final Square? selected;

  const ReversiaBoardPainter({
    required this.position,
    this.lastMove,
    this.hints = const [],
    this.selected,
  });

  static const Color lightSquare = Color(0xFFDEB887);
  static const Color darkSquare = Color(0xFFB08552);
  static const Color frontPieceColor = Color(0xFF2E3A59);
  static const Color backPieceColor = Color(0xFFC0392B);
  static const Color kingColor = Color(0xFFD4AF37);
  static const Color lastMoveColor = Color(0x55D4AF37);
  static const Color selectedBorderColor = Color(0xFFFFFFFF);
  static const Color hintColor = Color(0x992E7D32);

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = ReversiaPosition.boardSize;
    final cell = size.width / boardSize;

    final (lastFrom, lastTo) = switch (lastMove) {
      BoardMove(from: final from, to: final to) => (from, to),
      _ => (null, null),
    };

    for (var rank = 0; rank < boardSize; rank++) {
      for (var file = 0; file < boardSize; file++) {
        final square = Square(file, rank);
        final rect = Rect.fromLTWH(file * cell, rank * cell, cell, cell);

        final isDark = (file + rank).isEven;
        canvas.drawRect(
          rect,
          Paint()..color = isDark ? darkSquare : lightSquare,
        );

        if (square == lastFrom || square == lastTo) {
          canvas.drawRect(rect, Paint()..color = lastMoveColor);
        }

        final piece = position.at(square);
        if (piece != null) {
          _paintPiece(canvas, rect, piece);
        }

        if (hints.contains(square)) {
          canvas.drawCircle(
            rect.center,
            cell * 0.12,
            Paint()..color = hintColor,
          );
        }

        if (square == selected) {
          canvas.drawRect(
            rect.deflate(cell * 0.03),
            Paint()
              ..color = selectedBorderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.06,
          );
        }
      }
    }
  }

  void _paintPiece(Canvas canvas, Rect cellRect, ReversiaPiece piece) {
    final center = cellRect.center;
    final radius = cellRect.width * 0.38;
    final color = piece.type == ReversiaPieceType.king
        ? kingColor
        : (piece.face == ReversiaFace.front ? frontPieceColor : backPieceColor);

    canvas.drawCircle(center, radius, Paint()..color = Colors.black26);
    canvas.drawCircle(
      center.translate(0, -cellRect.height * 0.03),
      radius,
      Paint()..color = color,
    );

    if (piece.owner == position.sideToMove) {
      canvas.drawCircle(
        center.translate(0, -cellRect.height * 0.03),
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.12,
      );
    }

    if (piece.type == ReversiaPieceType.king) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '王',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center.translate(0, -cellRect.height * 0.03) -
            Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(ReversiaBoardPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.lastMove != lastMove ||
      oldDelegate.selected != selected ||
      !_sameSquares(oldDelegate.hints, hints);

  static bool _sameSquares(List<Square> a, List<Square> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
