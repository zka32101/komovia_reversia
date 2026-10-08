import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_core/testkit.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:test/test.dart';

void main() {
  final game = ReversiaGame();

  runGameContractTests<ReversiaPosition>(
    game,
    samplePosition: () => game.apply(
      game.initialPosition(),
      game.legalMoves(game.initialPosition()).first,
    ),
  );

  group('ReversiaGame extra checks', () {
    test('initial position has 18 pieces (9 per side) and the right side to move', () {
      final pos = game.initialPosition();
      expect(pos.cells.whereType<ReversiaPiece>().length, 18);
      expect(pos.pieceCount(Side.first), 9);
      expect(pos.pieceCount(Side.second), 9);
      expect(pos.sideToMove, Side.first);
      expect(pos.hasKing(Side.first), isTrue);
      expect(pos.hasKing(Side.second), isTrue);
    });

    test('every legal move from the initial position is a BoardMove', () {
      final moves = game.legalMoves(game.initialPosition());
      expect(moves, isNotEmpty);
      expect(moves, everyElement(isA<BoardMove>()));
    });

    test('moving onto an empty square just flips the piece\'s face', () {
      final pos = game.initialPosition();
      // (1, 1) in (file, rank) = row 1, col 1: a front-facing playerA piece
      // whose orthogonal move to (1, 2) (row 2, col 1) is onto an empty
      // square.
      const move = BoardMove(from: Square(1, 1), to: Square(1, 2));
      expect(game.legalMoves(pos), contains(move));

      final after = game.apply(pos, move);
      expect(after.at(const Square(1, 1)), isNull);
      final moved = after.at(const Square(1, 2))!;
      expect(moved.owner, Side.first);
      expect(moved.type, ReversiaPieceType.normal);
      expect(moved.face, ReversiaFace.back);
    });

    test('capturing a non-king piece converts it to the mover\'s side', () {
      final pos = ReversiaPosition(
        cells: [
          for (var i = 0; i < 36; i++)
            switch (i) {
              0 => const ReversiaPiece(
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front),
              1 => const ReversiaPiece(
                  type: ReversiaPieceType.normal, owner: Side.second, face: ReversiaFace.front),
              2 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front),
              8 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front),
              _ => null,
            },
        ],
        sideToMove: Side.first,
      );

      final move = const BoardMove(from: Square(0, 0), to: Square(1, 0));
      final after = game.apply(pos, move);

      final captured = after.at(const Square(1, 0))!;
      expect(captured.owner, Side.first);
      expect(captured.face, ReversiaFace.back);
      expect(game.result(after).isOngoing, isTrue);
    });

    test('capturing the king wins immediately', () {
      final pos = ReversiaPosition(
        cells: [
          for (var i = 0; i < 36; i++)
            switch (i) {
              0 => const ReversiaPiece(
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front),
              1 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front),
              2 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front),
              _ => null,
            },
        ],
        sideToMove: Side.first,
      );

      final move = const BoardMove(from: Square(0, 0), to: Square(1, 0));
      final after = game.apply(pos, move);

      expect(after.hasKing(Side.second), isFalse);
      final result = game.result(after);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.checkmate);
    });

    test('a side with no legal moves loses (stalemate reused as a loss)', () {
      // playerA's king is boxed into the (0,0) corner by its own 3 back-
      // facing pieces at (1,0)/(0,1)/(1,1); each of those pieces' single
      // on-board diagonal-2 jump is in turn blocked by occupying its
      // midpoint (any owner blocks a jump's midpoint, not just the
      // landing square -- see ReversiaGame._destinationsFor). playerB has
      // a king elsewhere so the game isn't already over for a different
      // reason.
      final pos = ReversiaPosition(
        cells: [
          for (var i = 0; i < 36; i++)
            switch (i) {
              0 => const ReversiaPiece( // (0,0)
                  type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front),
              1 => const ReversiaPiece( // (1,0)
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.back),
              6 => const ReversiaPiece( // (0,1)
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.back),
              7 => const ReversiaPiece( // (1,1)
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.back),
              8 => const ReversiaPiece( // (2,1): blocks (1,0)'s jump to (3,2)
                  type: ReversiaPieceType.normal, owner: Side.second, face: ReversiaFace.front),
              13 => const ReversiaPiece( // (1,2): blocks (0,1)'s jump to (2,3)
                  type: ReversiaPieceType.normal, owner: Side.second, face: ReversiaFace.front),
              14 => const ReversiaPiece( // (2,2): blocks (1,1)'s jump to (3,3)
                  type: ReversiaPieceType.normal, owner: Side.second, face: ReversiaFace.front),
              35 => const ReversiaPiece( // (5,5)
                  type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front),
              _ => null,
            },
        ],
        sideToMove: Side.first,
      );

      expect(game.legalMoves(pos), isEmpty);
      final result = game.result(pos);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.stalemate);
    });

    test('a position whose key occurs 3 times in historyKeys is a repetition '
        'loss for whoever just moved', () {
      // Built directly rather than from real play: with every move flipping
      // a normal piece's face (front <-> back, changing how it's allowed to
      // move next), reproducing the exact same board from legal moves takes
      // a longer cycle than is worth constructing here -- result() only
      // reads historyKeys' contents, not how they were produced.
      final pos = game.initialPosition();
      final key = game.positionKey(pos);
      final historyKeys = <Object>[key, 'elsewhere', key, 'elsewhere', key];

      final result = game.result(pos, historyKeys: historyKeys);
      expect(result.kind, ResultKind.win);
      expect(result.winner, pos.sideToMove);
      expect(result.reason, WinReason.repetition);
    });

    test('reaching the ply limit decides the game by piece count', () {
      final pos = ReversiaPosition(
        cells: [
          for (var i = 0; i < 36; i++)
            switch (i) {
              0 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.first, face: ReversiaFace.front),
              1 => const ReversiaPiece(
                  type: ReversiaPieceType.normal, owner: Side.first, face: ReversiaFace.front),
              35 => const ReversiaPiece(
                  type: ReversiaPieceType.king, owner: Side.second, face: ReversiaFace.front),
              _ => null,
            },
        ],
        sideToMove: Side.first,
      );
      // Distinct dummy keys so this doesn't also satisfy the repetition
      // check -- only this test's length matters, not what's in it.
      final historyKeys = List<Object>.generate(
        ReversiaGame.plyLimit + 1,
        (i) => 'ply-$i',
      );

      final result = game.result(pos, historyKeys: historyKeys);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.score);
    });

    test('resigning ends the game for the opponent, same as the shared contract test', () {
      final pos = game.initialPosition();
      final after = game.apply(pos, const ResignMove(Side.first));
      final result = game.result(after);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.resignation);
    });
  });
}
