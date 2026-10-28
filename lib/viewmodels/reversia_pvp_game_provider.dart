import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/reversia_pvp_game.dart';
import '../services/reversia_pvp_game_service.dart';

/// komovia_shogiの`shogi_pvp_game_provider.dart`と同じ役割（reversia向け）。
/// `ReversiaPvpGameService`の薄いRiverpodラッパー。
final reversiaPvpGameServiceProvider = Provider<ReversiaPvpGameService>((ref) {
  return ReversiaPvpGameService(FirebaseFirestore.instance);
});

/// 対局のリアルタイム盤面（両対局者共通で購読）。
final reversiaPvpGameStreamProvider =
    StreamProvider.family<ReversiaPvpGame, String>((ref, gameId) {
  return ref.watch(reversiaPvpGameServiceProvider).watchGame(gameId);
});

/// (gameId, uid, move)を渡して着手する。拒否された場合はfalseを返す。
final applyReversiaPvpMoveProvider =
    Provider<Future<bool> Function(String gameId, String uid, Move move)>((
  ref,
) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return (gameId, uid, move) {
    return service.applyMove(gameId: gameId, uid: uid, move: move);
  };
});

/// 投了する。
final resignReversiaPvpGameProvider =
    Provider<Future<void> Function(String gameId, String uid)>((ref) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return (gameId, uid) {
    return service.resign(gameId: gameId, uid: uid);
  };
});

/// 新しいPvP対局を作成する。
final createReversiaPvpGameProvider = Provider<
    Future<ReversiaPvpGame> Function({
      required String firstUid,
      required String firstDisplayName,
      required String secondUid,
      required String secondDisplayName,
      String? matchId,
    })>((ref) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return ({
    required firstUid,
    required firstDisplayName,
    required secondUid,
    required secondDisplayName,
    matchId,
  }) {
    return service.createGame(
      firstUid: firstUid,
      firstDisplayName: firstDisplayName,
      secondUid: secondUid,
      secondDisplayName: secondDisplayName,
      matchId: matchId,
    );
  };
});
