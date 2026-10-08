import 'package:komovia_core/komovia_core.dart';

import 'reversia_position.dart';

const _orthogonal = [
  [0, -1],
  [0, 1],
  [-1, 0],
  [1, 0],
];

const _diagonal2 = [
  [-2, -2],
  [-2, 2],
  [2, -2],
  [2, 2],
];

/// Reversia: a 6x6 board game where pieces flip between an orthogonal-
/// moving "front" face and a diagonal-jumping "back" face, capturing by
/// landing on an opponent's piece and converting it to the mover's side
/// (the one Othello-like element) rather than removing it. Capturing the
/// king wins immediately.
///
/// Ported from project-015 (`lib/engine/board.dart`, `move_generator.dart`,
/// `game_state.dart`). See [ReversiaPosition] and this class's method docs
/// for what changed to fit `komovia_core`'s `Game` interface.
class ReversiaGame implements Game<ReversiaPosition> {
  /// Ported from project-015's `GameState.repetitionLimit`: the same
  /// position (board + side to move) recurring this many times is a loss
  /// for whoever just moved into it.
  static const int repetitionLimit = 3;

  /// Ported from project-015's `GameState.plyLimit`: the game is decided
  /// by piece count once this many plies have been played.
  static const int plyLimit = 60;

  @override
  String get id => 'reversia';

  @override
  ReversiaPosition initialPosition({Map<String, Object?> options = const {}}) {
    final cells = List<ReversiaPiece?>.filled(
      ReversiaPosition.boardSize * ReversiaPosition.boardSize,
      null,
    );

    void placeBackRow(int row, Side owner) {
      for (var col = 0; col < ReversiaPosition.boardSize; col++) {
        cells[row * ReversiaPosition.boardSize + col] = ReversiaPiece(
          type: ReversiaPieceType.normal,
          owner: owner,
          face: ReversiaFace.front,
        );
      }
    }

    void placeSecondRow(int row, Side owner) {
      cells[row * ReversiaPosition.boardSize + 1] = ReversiaPiece(
        type: ReversiaPieceType.normal,
        owner: owner,
        face: ReversiaFace.front,
      );
      cells[row * ReversiaPosition.boardSize + 2] = ReversiaPiece(
        type: ReversiaPieceType.king,
        owner: owner,
        face: ReversiaFace.front,
      );
      cells[row * ReversiaPosition.boardSize + 3] = ReversiaPiece(
        type: ReversiaPieceType.normal,
        owner: owner,
        face: ReversiaFace.front,
      );
    }

    placeBackRow(0, Side.first);
    placeSecondRow(1, Side.first);
    placeSecondRow(4, Side.second);
    placeBackRow(5, Side.second);

    return ReversiaPosition(cells: cells, sideToMove: Side.first);
  }

  @override
  Object positionKey(ReversiaPosition position) => encode(position);

  @override
  List<Move> legalMoves(
    ReversiaPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (!result(position, historyKeys: historyKeys).isOngoing) return const [];
    return _rawLegalMoves(position);
  }

  /// [legalMoves] minus the "is the game already over" check -- [result]
  /// needs this list to decide the no-legal-moves loss, so it can't call
  /// [legalMoves] itself without recursing.
  List<Move> _rawLegalMoves(ReversiaPosition position) {
    final moves = <Move>[];
    for (var row = 0; row < ReversiaPosition.boardSize; row++) {
      for (var col = 0; col < ReversiaPosition.boardSize; col++) {
        final from = Square(col, row);
        final piece = position.at(from);
        if (piece == null || piece.owner != position.sideToMove) continue;
        for (final to in _destinationsFor(position, from, piece)) {
          moves.add(BoardMove(from: from, to: to));
        }
      }
    }
    return moves;
  }

  List<Square> _destinationsFor(
    ReversiaPosition position,
    Square from,
    ReversiaPiece piece,
  ) {
    final dirs = piece.type == ReversiaPieceType.king
        ? const [
            [-1, 0], [1, 0], [0, -1], [0, 1],
            [-1, -1], [-1, 1], [1, -1], [1, 1],
          ]
        : (piece.face == ReversiaFace.front ? _orthogonal : _diagonal2);

    final results = <Square>[];
    for (final d in dirs) {
      final to = Square(from.file + d[0], from.rank + d[1]);
      if (!_onBoard(to)) continue;

      if (piece.type == ReversiaPieceType.normal && piece.face == ReversiaFace.back) {
        final mid = Square(from.file + d[0] ~/ 2, from.rank + d[1] ~/ 2);
        if (position.at(mid) != null) continue;
      }

      final target = position.at(to);
      if (target != null && target.owner == piece.owner) continue;
      results.add(to);
    }
    return results;
  }

  static bool _onBoard(Square s) =>
      s.file >= 0 &&
      s.file < ReversiaPosition.boardSize &&
      s.rank >= 0 &&
      s.rank < ReversiaPosition.boardSize;

  @override
  ReversiaPosition apply(
    ReversiaPosition position,
    Move move, {
    List<Object> historyKeys = const [],
  }) {
    switch (move) {
      case BoardMove(from: final from, to: final to):
        final piece = position.at(from);
        if (piece == null || piece.owner != position.sideToMove) {
          throw ArgumentError('Illegal move $move for $position');
        }
        final target = position.at(to);
        final movedPiece = piece.type == ReversiaPieceType.king
            ? piece
            : piece.copyWith(face: piece.face.flipped);

        // King captured: the king's square is overwritten by the mover's
        // own piece (flipping face if it's a normal piece), not derived
        // from the captured king. Non-king capture: the captured piece
        // converts to the mover's side and flips face instead. Ported
        // from `GameState.applyMove`'s two capture branches.
        final landingPiece = (target != null && target.type != ReversiaPieceType.king)
            ? target.copyWith(owner: position.sideToMove, face: target.face.flipped)
            : movedPiece;

        final cells = List<ReversiaPiece?>.of(position.cells);
        cells[ReversiaPosition.indexOf(from)] = null;
        cells[ReversiaPosition.indexOf(to)] = landingPiece;

        return ReversiaPosition(
          cells: cells,
          sideToMove: position.sideToMove.opponent,
        );

      case ResignMove(side: final side):
        return position.copyWith(resignedBy: side);

      case DropMove():
      case PassMove():
        throw ArgumentError('Reversia has no drops or passes: $move');
    }
  }

  @override
  GameResult result(
    ReversiaPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (position.resignedBy != null) {
      return GameResult.win(position.resignedBy!.opponent, WinReason.resignation);
    }

    if (!position.hasKing(Side.first)) {
      return GameResult.win(Side.second, WinReason.checkmate);
    }
    if (!position.hasKing(Side.second)) {
      return GameResult.win(Side.first, WinReason.checkmate);
    }

    // Ported from `GameState.applyMove`'s repetition check: historyKeys
    // includes `positionKey(position)` itself (per the Game.result
    // contract), so counting occurrences of the current key directly
    // tells us whether this exact position (board + side to move) has
    // now recurred `repetitionLimit` times. The side that just moved
    // (the opponent of position.sideToMove, since the turn has already
    // flipped) caused the repeat and loses.
    if (historyKeys.isNotEmpty) {
      final key = positionKey(position);
      final occurrences = historyKeys.where((k) => k == key).length;
      if (occurrences >= repetitionLimit) {
        return GameResult.win(position.sideToMove, WinReason.repetition);
      }
    }

    // Ported from `GameState.applyMove`'s ply-limit check. historyKeys is
    // every position up to and including this one (oldest first), so its
    // length is the ply count plus one for the initial position -- when a
    // caller doesn't thread history at all (historyKeys is empty), there
    // is no ply count to compare, so this never fires.
    if (historyKeys.isNotEmpty) {
      final plyCount = historyKeys.length - 1;
      if (plyCount >= plyLimit) {
        final firstCount = position.pieceCount(Side.first);
        final secondCount = position.pieceCount(Side.second);
        if (firstCount > secondCount) {
          return GameResult.win(Side.first, WinReason.score);
        }
        if (secondCount > firstCount) {
          return GameResult.win(Side.second, WinReason.score);
        }
        return const GameResult.draw(WinReason.score);
      }
    }

    // Ported from project-015's `GameState.declareNoMovesLoss`, which the
    // original caller (GameViewModel) had to invoke explicitly after
    // seeing `MoveGenerator.legalMovesFor` return empty. Folded into
    // `result` here so it holds for any caller, matching the "stalemate
    // reuse" note in this package's README: unlike chess, a side with no
    // legal moves *loses* in Reversia rather than drawing.
    if (_rawLegalMoves(position).isEmpty) {
      return GameResult.win(position.sideToMove.opponent, WinReason.stalemate);
    }

    return GameResult.ongoing;
  }

  @override
  String encode(ReversiaPosition position) {
    final sb = StringBuffer();
    for (final p in position.cells) {
      if (p == null) {
        sb.write('--');
        continue;
      }
      sb.write(p.owner == Side.first ? 'A' : 'B');
      sb.write(switch (p.type) {
        ReversiaPieceType.king => 'K',
        ReversiaPieceType.normal =>
          p.face == ReversiaFace.front ? 'f' : 'b',
      });
    }
    sb.write('|');
    sb.write(position.sideToMove == Side.first ? 'A' : 'B');
    sb.write('|');
    sb.write(switch (position.resignedBy) {
      null => '-',
      Side.first => 'A',
      Side.second => 'B',
    });
    return sb.toString();
  }

  @override
  ReversiaPosition decode(String notation) {
    final parts = notation.split('|');
    const cellCount = ReversiaPosition.boardSize * ReversiaPosition.boardSize;
    if (parts.length != 3 || parts[0].length != cellCount * 2) {
      throw FormatException('Invalid Reversia notation: $notation');
    }

    final cells = <ReversiaPiece?>[];
    for (var i = 0; i < cellCount; i++) {
      final token = parts[0].substring(i * 2, i * 2 + 2);
      cells.add(_decodeCell(token, notation));
    }

    final sideToMove = _decodeSide(parts[1], notation);
    final resignedBy = parts[2] == '-' ? null : _decodeSide(parts[2], notation);

    return ReversiaPosition(
      cells: cells,
      sideToMove: sideToMove,
      resignedBy: resignedBy,
    );
  }

  static ReversiaPiece? _decodeCell(String token, String source) {
    if (token == '--') return null;
    if (token.length != 2) {
      throw FormatException('Invalid cell "$token" in: $source');
    }
    final owner = _decodeSide(token[0], source);
    return switch (token[1]) {
      'K' => ReversiaPiece(type: ReversiaPieceType.king, owner: owner, face: ReversiaFace.front),
      'f' => ReversiaPiece(type: ReversiaPieceType.normal, owner: owner, face: ReversiaFace.front),
      'b' => ReversiaPiece(type: ReversiaPieceType.normal, owner: owner, face: ReversiaFace.back),
      _ => throw FormatException('Invalid cell "$token" in: $source'),
    };
  }

  static Side _decodeSide(String c, String source) => switch (c) {
        'A' => Side.first,
        'B' => Side.second,
        _ => throw FormatException('Invalid side "$c" in: $source'),
      };

  // --- GameRecord <-> notation ---------------------------------------
  //
  // Not a real kifu format (Reversia has no established one) -- just
  // enough for Game.exportRecord/importRecord to round-trip, mirroring
  // komovia_core's tictactoe fixture's line-based codec.

  @override
  String exportRecord(GameRecord record) {
    final lines = <String>[
      record.gameId,
      _encodeResult(record.result),
      for (final m in record.moves) '${m.number},${_sideChar(m.side)},${_encodeMove(m.move)}',
    ];
    return lines.join('\n');
  }

  @override
  GameRecord importRecord(String notation) {
    final lines = notation.split('\n');
    if (lines.length < 2 || lines[0] != id) {
      throw FormatException('Invalid Reversia record: $notation');
    }
    final result = _decodeResult(lines[1]);
    final moves = [
      for (final line in lines.skip(2))
        if (line.isNotEmpty) _decodeRecordedMove(line, notation),
    ];
    return GameRecord(gameId: lines[0], moves: moves, result: result);
  }

  static String _sideChar(Side s) => s == Side.first ? 'A' : 'B';

  static String _encodeMove(Move m) => switch (m) {
        BoardMove(from: final f, to: final t, promote: final p) =>
          'B,${f.file},${f.rank},${t.file},${t.rank},${p ? 1 : 0}',
        DropMove(pieceType: final pt, to: final t) => 'D,$pt,${t.file},${t.rank}',
        PassMove() => 'P',
        ResignMove(side: final s) => 'R,${_sideChar(s)}',
      };

  static Move _decodeMove(List<String> t, String source) {
    if (t.isEmpty) throw FormatException('Empty move in: $source');
    switch (t[0]) {
      case 'B' when t.length == 6:
        return BoardMove(
          from: Square(int.parse(t[1]), int.parse(t[2])),
          to: Square(int.parse(t[3]), int.parse(t[4])),
          promote: t[5] == '1',
        );
      case 'D' when t.length == 4:
        return DropMove(pieceType: t[1], to: Square(int.parse(t[2]), int.parse(t[3])));
      case 'P' when t.length == 1:
        return const PassMove();
      case 'R' when t.length == 2:
        return ResignMove(_decodeSide(t[1], source));
      default:
        throw FormatException('Invalid move "${t.join(',')}" in: $source');
    }
  }

  static RecordedMove _decodeRecordedMove(String line, String source) {
    final parts = line.split(',');
    if (parts.length < 3) {
      throw FormatException('Invalid move line "$line" in: $source');
    }
    final number = int.tryParse(parts[0]);
    if (number == null) {
      throw FormatException('Invalid move number "${parts[0]}" in: $source');
    }
    return RecordedMove(
      number: number,
      side: _decodeSide(parts[1], source),
      move: _decodeMove(parts.sublist(2), source),
    );
  }

  static String _encodeResult(GameResult r) {
    final winner = r.winner == null ? '' : _sideChar(r.winner!);
    return '${r.kind.name},$winner,${r.reason?.name ?? ''}';
  }

  static GameResult _decodeResult(String s) {
    final parts = s.split(',');
    if (parts.length != 3) throw FormatException('Invalid result: $s');

    ResultKind? kind;
    for (final k in ResultKind.values) {
      if (k.name == parts[0]) kind = k;
    }
    if (kind == null) throw FormatException('Invalid result kind: $s');

    final winner = parts[1].isEmpty ? null : _decodeSide(parts[1], s);

    WinReason? reason;
    for (final w in WinReason.values) {
      if (w.name == parts[2]) reason = w;
    }
    if (parts[2].isNotEmpty && reason == null) {
      throw FormatException('Invalid win reason: $s');
    }

    return switch (kind) {
      ResultKind.ongoing => GameResult.ongoing,
      ResultKind.win => GameResult.win(winner!, reason!),
      ResultKind.draw => GameResult.draw(reason!),
    };
  }
}
