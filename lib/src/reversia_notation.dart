import 'package:komovia_core/komovia_core.dart';

/// 標準代数記法（列a-f + 行1-6）での表記 - project-015の
/// `GameNotation._squareToNotation`と同じ規約（`Square.file`が列、
/// `Square.rank`が行）。
String reversiaSquareNotation(Square square) {
  final col = String.fromCharCode(97 + square.file);
  final row = square.rank + 1;
  return '$col$row';
}

/// [move]の表記。`BoardMove`は`<from><to>`（例: `c4d5`）、`ResignMove`は
/// `投了`。Reversiaに`DropMove`/`PassMove`は存在しない
/// （`ReversiaGame.apply`参照）ため扱わない。
String reversiaMoveNotation(Move move) {
  return switch (move) {
    BoardMove(from: final from, to: final to) =>
      '${reversiaSquareNotation(from)}${reversiaSquareNotation(to)}',
    ResignMove() => '投了',
    _ => move.toString(),
  };
}
