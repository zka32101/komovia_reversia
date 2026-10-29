import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/reversia_pvp_game.dart';
import '../src/reversia_game.dart';
import '../src/reversia_position.dart';

/// PvP対局サービス - マッチング成立後の2人プレイヤー間対局。
/// komovia_shogiの`ShogiPvpGameService`と同じ役割だが、盤面はFirestoreへ
/// 直接エンコードせず、`ReversiaPvpGame.movesRecord`（着手レコード文字列）
/// を都度初期局面から打ち直して再構成する（`ReversiaPvpGame`のクラス
/// コメント参照）。放置対局の救済やライブ観戦はこのPRの範囲外 - 後続PRで
/// 追加する。
class ReversiaPvpGameService {
  ReversiaPvpGameService(this._firestore, {ReversiaGame? game})
      : _game = game ?? ReversiaGame();

  final FirebaseFirestore _firestore;
  final ReversiaGame _game;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('reversia_pvp_games');

  Future<ReversiaPvpGame> createGame({
    required String firstUid,
    required String firstDisplayName,
    required String secondUid,
    required String secondDisplayName,
    String? matchId,
  }) async {
    final docRef = _games.doc();
    final game = ReversiaPvpGame(
      id: docRef.id,
      firstUid: firstUid,
      firstDisplayName: firstDisplayName,
      secondUid: secondUid,
      secondDisplayName: secondDisplayName,
      isFirstTurn: true,
      movesCount: 0,
      status: 'active',
      matchId: matchId,
      createdAt: DateTime.now(),
    );
    await docRef.set(game.toFirestore());
    return game;
  }

  Future<ReversiaPvpGame?> getGame(String gameId) async {
    final doc = await _games.doc(gameId).get();
    if (!doc.exists) return null;
    return ReversiaPvpGame.fromFirestore(doc);
  }

  Stream<ReversiaPvpGame> watchGame(String gameId) =>
      _games.doc(gameId).snapshots().map(ReversiaPvpGame.fromFirestore);

  /// [movesRecord]から現局面・局面履歴（千日手判定用）・着手リストを
  /// 初期局面から打ち直して再構成する。
  ({ReversiaPosition position, List<Object> historyKeys, List<RecordedMove> moves})
      _replay(String movesRecord) {
    var position = _game.initialPosition();
    final historyKeys = <Object>[_game.positionKey(position)];
    final moves = <RecordedMove>[];
    if (movesRecord.isNotEmpty) {
      final record = _game.importRecord(movesRecord);
      for (final recorded in record.moves) {
        position = _game.apply(position, recorded.move);
        historyKeys.add(_game.positionKey(position));
        moves.add(recorded);
      }
    }
    return (position: position, historyKeys: historyKeys, moves: moves);
  }

  /// [move]を適用する。手番でない・非対局者・終局済み・非合法手の
  /// いずれかであれば何もせず`false`を返す。
  Future<bool> applyMove({
    required String gameId,
    required String uid,
    required Move move,
  }) {
    return _firestore.runTransaction<bool>((transaction) async {
      final docRef = _games.doc(gameId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      final pvp = ReversiaPvpGame.fromFirestore(snapshot);
      if (!pvp.isActive || !pvp.isTurnOf(uid)) return false;

      final replay = _replay(pvp.movesRecord);
      final legal = _game.legalMoves(
        replay.position,
        historyKeys: replay.historyKeys,
      );
      if (!legal.contains(move)) return false;

      final side = replay.position.sideToMove;
      final newPosition = _game.apply(
        replay.position,
        move,
        historyKeys: replay.historyKeys,
      );
      final newHistoryKeys = [...replay.historyKeys, _game.positionKey(newPosition)];
      final newMoveNumber = replay.moves.length + 1;
      final newMoves = [
        ...replay.moves,
        RecordedMove(number: newMoveNumber, side: side, move: move),
      ];

      final result = _game.result(newPosition, historyKeys: newHistoryKeys);
      final newRecord = _game.exportRecord(
        GameRecord(gameId: _game.id, moves: newMoves, result: result),
      );

      final updates = <String, Object?>{
        'movesRecord': newRecord,
        'isFirstTurn': newPosition.sideToMove == Side.first,
        'movesCount': newMoveNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!result.isOngoing) {
        updates['status'] = 'finished';
        if (result.kind == ResultKind.win) {
          updates['winnerUid'] =
              result.winner == Side.first ? pvp.firstUid : pvp.secondUid;
          updates['result'] = result.reason == WinReason.resignation
              ? 'resignation'
              : 'victory';
        } else {
          updates['result'] = 'draw';
        }
      }

      transaction.update(docRef, updates);
      return true;
    });
  }

  /// 相手が長期間応答していない（`updatedAt`からこの期間が経過している）
  /// 対局を、放置勝ちとして終局させる。komovia_goの`PvpGameService.
  /// claimAbandonmentForfeit`と同じ役割・同じ閾値 - 「NO TIMERS」方針
  /// （対局中に時間制限を課さない）とは別物で、何日も現実に動きが無い
  /// 対局を永久に「進行中」で残さないための救済措置。
  static const Duration abandonmentThreshold = Duration(hours: 48);

  /// トランザクション内で読み取り・判定・書き込みを行うため、
  /// applyMove/resignと同時に呼ばれても後勝ちで結果が上書きされない。
  Future<void> claimAbandonmentForfeit({
    required String gameId,
    required String claimantUid,
  }) {
    return _firestore.runTransaction<void>((transaction) async {
      final docRef = _games.doc(gameId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final pvp = ReversiaPvpGame.fromFirestore(snapshot);
      if (!pvp.canClaimAbandonmentForfeit(
        claimantUid,
        threshold: abandonmentThreshold,
      )) {
        return;
      }

      transaction.update(docRef, {
        'status': 'finished',
        'winnerUid': claimantUid,
        'result': 'forfeit',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 投了する。非対局者・終局済みであれば何もしない。
  Future<void> resign({required String gameId, required String uid}) {
    return _firestore.runTransaction<void>((transaction) async {
      final docRef = _games.doc(gameId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final pvp = ReversiaPvpGame.fromFirestore(snapshot);
      if (!pvp.isActive) return;

      final color = pvp.playerColorOf(uid);
      if (color == 0) return;
      final winnerUid = color == 1 ? pvp.secondUid : pvp.firstUid;

      transaction.update(docRef, {
        'status': 'finished',
        'winnerUid': winnerUid,
        'result': 'resignation',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
