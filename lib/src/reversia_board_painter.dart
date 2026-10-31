import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import 'reversia_board_theme.dart';
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
  final ReversiaBoardTheme theme;

  /// 盤面を180度回転して描く - 後手視点（下側に自分の駒が来るように）
  /// でプレイしたい場合向け。局面・着手判定のモデルは一切変わらず、
  /// 描画位置（と[ReversiaBoardRenderer.squareAt]の逆変換）だけが影響
  /// を受ける - competitor Othello/Reversiアプリによくある「盤面を
  /// 反転して見る」機能。
  final bool flipped;

  const ReversiaBoardPainter({
    required this.position,
    this.lastMove,
    this.hints = const [],
    this.selected,
    this.theme = ReversiaBoardTheme.classic,
    this.flipped = false,
  });

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
        final displayFile = flipped ? boardSize - 1 - file : file;
        final displayRank = flipped ? boardSize - 1 - rank : rank;
        final rect = Rect.fromLTWH(displayFile * cell, displayRank * cell, cell, cell);

        final isDark = (file + rank).isEven;
        canvas.drawRect(
          rect,
          Paint()..color = isDark ? theme.darkSquare : theme.lightSquare,
        );
        if (theme.gridLineColor != null) {
          canvas.drawRect(
            rect,
            Paint()
              ..color = theme.gridLineColor!
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.03,
          );
        }

        if (square == lastFrom || square == lastTo) {
          canvas.drawRect(rect, Paint()..color = theme.lastMoveColor);
        }

        final piece = position.at(square);
        if (piece != null) {
          _paintPiece(canvas, rect, piece);
        }

        if (hints.contains(square)) {
          canvas.drawCircle(
            rect.center,
            cell * 0.12,
            Paint()..color = theme.hintColor,
          );
        }

        if (square == selected) {
          canvas.drawRect(
            rect.deflate(cell * 0.03),
            Paint()
              ..color = theme.selectedBorderColor
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
        ? theme.kingColor
        : (piece.face == ReversiaFace.front ? theme.frontPieceColor : theme.backPieceColor);

    canvas.drawCircle(center, radius, Paint()..color = Colors.black26);
    canvas.drawCircle(
      center.translate(0, -cellRect.height * 0.03),
      radius,
      Paint()..color = color,
    );

    if (theme.discGloss) {
      canvas.drawCircle(
        center.translate(-radius * 0.3, -cellRect.height * 0.03 - radius * 0.3),
        radius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }

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
      oldDelegate.theme != theme ||
      oldDelegate.flipped != flipped ||
      !_sameSquares(oldDelegate.hints, hints);

  static bool _sameSquares(List<Square> a, List<Square> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
