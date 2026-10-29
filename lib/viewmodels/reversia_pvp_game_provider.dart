import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/reversia_pvp_game.dart';
import '../services/reversia_pvp_game_service.dart';
import 'achievement_provider.dart';
import 'leaderboard_provider.dart';
import 'tournament_provider.dart';

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

/// [uid]が参加している進行中のPvP対局一覧（`ReversiaPvpGamesListScreen`用）。
final reversiaUserActivePvpGamesProvider =
    FutureProvider.family<List<ReversiaPvpGame>, String>((ref, uid) {
  return ref.watch(reversiaPvpGameServiceProvider).getUserActiveGames(uid);
});

/// (gameId, uid, move)を渡して着手する。拒否された場合はfalseを返す。
/// 着手によって対局が終局した場合、両対局者のレーティングを更新する
/// （best-effort、対局進行自体はブロックしない）。
final applyReversiaPvpMoveProvider =
    Provider<Future<bool> Function(String gameId, String uid, Move move)>((
  ref,
) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return (gameId, uid, move) async {
    final applied =
        await service.applyMove(gameId: gameId, uid: uid, move: move);
    if (applied) await _onReversiaPvpGameFinished(ref, service, gameId);
    return applied;
  };
});

/// 投了する。投了によって終局するため、常にレーティングを更新する。
final resignReversiaPvpGameProvider =
    Provider<Future<void> Function(String gameId, String uid)>((ref) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return (gameId, uid) async {
    await service.resign(gameId: gameId, uid: uid);
    await _onReversiaPvpGameFinished(ref, service, gameId);
  };
});

/// 相手が長期間応答していない対局を放置勝ちとして終局させる。
/// applyMove/resignと同じく、終局したらレーティングを更新する。
final claimReversiaAbandonmentForfeitProvider =
    Provider<Future<void> Function(String gameId, String claimantUid)>((ref) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return (gameId, claimantUid) async {
    await service.claimAbandonmentForfeit(
      gameId: gameId,
      claimantUid: claimantUid,
    );
    await _onReversiaPvpGameFinished(ref, service, gameId);
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

/// トーナメント試合用の対局作成。両対局者がほぼ同時に開始しても対局が
/// 2つ作られないよう、Firestoreトランザクションで排他制御される
/// （`ReversiaPvpGameService.createGameForTournamentMatch`参照）。
final createTournamentReversiaGameProvider = Provider<
    Future<String> Function({
      required String tournamentId,
      required String matchId,
      required String firstUid,
      required String firstDisplayName,
      required String secondUid,
      required String secondDisplayName,
    })>((ref) {
  final service = ref.watch(reversiaPvpGameServiceProvider);
  return ({
    required tournamentId,
    required matchId,
    required firstUid,
    required firstDisplayName,
    required secondUid,
    required secondDisplayName,
  }) {
    return service.createGameForTournamentMatch(
      tournamentId: tournamentId,
      matchId: matchId,
      firstUid: firstUid,
      firstDisplayName: firstDisplayName,
      secondUid: secondUid,
      secondDisplayName: secondDisplayName,
    );
  };
});

/// 終局したPvP対局の結果を標準的なElo式で両対局者のレーティングに反映
/// する（K=32固定）。komovia_goの`pvp_game_provider.dart`の
/// `_updateEloRatings`と同じ役割（reversia向け）。失敗はbest-effortで
/// 握りつぶす — 対局自体は常にこのエラーに関係なく継続できる。
Future<void> _onReversiaPvpGameFinished(
  Ref ref,
  ReversiaPvpGameService service,
  String gameId,
) async {
  ReversiaPvpGame? game;
  try {
    game = await service.getGame(gameId);
  } catch (_) {
    return;
  }
  if (game == null || !game.isFinished) return;

  try {
    await _updateReversiaPvpEloRatings(ref, game);
  } catch (_) {
    // best-effort: 対局自体は常に続行できる
  }

  if (game.tournamentId == null ||
      game.tournamentMatchId == null ||
      game.winnerUid == null) {
    return; // トーナメントに紐づいていない、または引き分け
  }
  try {
    await ref.read(tournamentServiceProvider).recordMatchResult(
          game.tournamentId!,
          game.tournamentMatchId!,
          game.winnerUid!,
          {
            game.firstUid: game.firstDisplayName,
            game.secondUid: game.secondDisplayName,
          },
        );
  } catch (_) {
    // best-effort: 対局自体は常に続行できる
  }
}

Future<void> _updateReversiaPvpEloRatings(Ref ref, ReversiaPvpGame game) async {
  const kFactor = 32;
  final leaderboardService = ref.read(leaderboardServiceProvider);

  final firstEntry = await leaderboardService.getEntry(game.firstUid);
  final secondEntry = await leaderboardService.getEntry(game.secondUid);
  final firstRating = firstEntry?.rating ?? 1200;
  final secondRating = secondEntry?.rating ?? 1200;

  final double firstScore;
  if (game.winnerUid == game.firstUid) {
    firstScore = 1.0;
  } else if (game.winnerUid == game.secondUid) {
    firstScore = 0.0;
  } else {
    firstScore = 0.5; // 引き分け
  }
  final secondScore = 1.0 - firstScore;

  final expectedFirst =
      1.0 / (1.0 + math.pow(10, (secondRating - firstRating) / 400));
  final expectedSecond = 1.0 - expectedFirst;

  final firstDelta = (kFactor * (firstScore - expectedFirst)).round();
  final secondDelta = (kFactor * (secondScore - expectedSecond)).round();

  await leaderboardService.incrementStats(
    uid: game.firstUid,
    displayName: game.firstDisplayName,
    ratingDelta: firstDelta,
    gamesDelta: 1,
    winsDelta: firstScore == 1.0 ? 1 : 0,
  );
  await leaderboardService.incrementStats(
    uid: game.secondUid,
    displayName: game.secondDisplayName,
    ratingDelta: secondDelta,
    gamesDelta: 1,
    winsDelta: secondScore == 1.0 ? 1 : 0,
  );

  final checkAndUnlock = ref.read(checkAndUnlockAchievementsProvider);
  if (firstScore == 1.0) await checkAndUnlock(game.firstUid);
  if (secondScore == 1.0) await checkAndUnlock(game.secondUid);
}
