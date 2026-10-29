import 'package:flutter/material.dart';

/// 盤・駒の配色テーマ。競合Othello/Reversiアプリの多くが持つ「盤面の
/// 見た目を選べる」機能 - `ReversiaBoardPainter`は元々これらの色を
/// `static const`で固定していたが（project-015からの移植時点では配色
/// 1種類しか無かった）、この型に切り出して複数選べるようにした。
///
/// `classic`の値は元の`ReversiaBoardPainter`の`static const`と完全に
/// 同じなので、テーマ機能の追加自体は既存の見た目に影響しない。
class ReversiaBoardTheme {
  final String id;
  final String label;
  final Color lightSquare;
  final Color darkSquare;
  final Color frontPieceColor;
  final Color backPieceColor;
  final Color kingColor;
  final Color lastMoveColor;
  final Color selectedBorderColor;
  final Color hintColor;

  const ReversiaBoardTheme({
    required this.id,
    required this.label,
    required this.lightSquare,
    required this.darkSquare,
    required this.frontPieceColor,
    required this.backPieceColor,
    required this.kingColor,
    required this.lastMoveColor,
    required this.selectedBorderColor,
    required this.hintColor,
  });

  static const classic = ReversiaBoardTheme(
    id: 'classic',
    label: '木目',
    lightSquare: Color(0xFFDEB887),
    darkSquare: Color(0xFFB08552),
    frontPieceColor: Color(0xFF2E3A59),
    backPieceColor: Color(0xFFC0392B),
    kingColor: Color(0xFFD4AF37),
    lastMoveColor: Color(0x55D4AF37),
    selectedBorderColor: Color(0xFFFFFFFF),
    hintColor: Color(0x992E7D32),
  );

  static const sumi = ReversiaBoardTheme(
    id: 'sumi',
    label: '墨',
    lightSquare: Color(0xFF4A4A4A),
    darkSquare: Color(0xFF2B2B2B),
    frontPieceColor: Color(0xFFE8E8E8),
    backPieceColor: Color(0xFF8E1F1F),
    kingColor: Color(0xFFD4AF37),
    lastMoveColor: Color(0x55D4AF37),
    selectedBorderColor: Color(0xFFFFFFFF),
    hintColor: Color(0x9950C878),
  );

  static const emerald = ReversiaBoardTheme(
    id: 'emerald',
    label: '翡翠',
    lightSquare: Color(0xFF2F6F4F),
    darkSquare: Color(0xFF1F4D36),
    frontPieceColor: Color(0xFF1A1A2E),
    backPieceColor: Color(0xFFE8D174),
    kingColor: Color(0xFFD4AF37),
    lastMoveColor: Color(0x55D4AF37),
    selectedBorderColor: Color(0xFFFFFFFF),
    hintColor: Color(0x99FFFFFF),
  );

  static const all = [classic, sumi, emerald];

  static ReversiaBoardTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classic);
}
