import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import 'notification_service.dart';

/// トーナメント作成/参加/ブラケット進行 - komovia_shogiの
/// `tournament_service.dart`と同じ役割（komovia_coreの共通モデル
/// `Tournament`/`TournamentMatch`を使用）。シングルエリミネーション
/// （奇数人数の不戦勝対応含む）のみ実装 - round_robin/swissは、GoEnの
/// 本家実装がこの段階ではまだシングルエリミネーションしか作っていなか
/// った事実に合わせて、意図的に未実装のままにしている（過剰な前実装を
/// 避けるため）。
class TournamentService {
  TournamentService({
    FirebaseFirestore? firestore,
    NotificationService? notifications,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications;

  final FirebaseFirestore _firestore;
  final NotificationService? _notifications;

  CollectionReference<Map<String, Object?>> get _tournaments =>
      _firestore.collection('tournaments');

  CollectionReference<Map<String, Object?>> _matchesOf(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('matches');

  Future<Tournament> createTournament({
    required String name,
    required String description,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
    int maxParticipants = 8,
    String format = 'single_elimination',
    int boardSize = 6,
  }) async {
    final doc = _tournaments.doc();
    final tournament = Tournament(
      id: doc.id,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      maxParticipants: maxParticipants,
      format: format,
      status: 'upcoming',
      participantUids: [createdBy],
      createdBy: createdBy,
      boardSize: boardSize,
      createdAt: DateTime.now(),
    );
    await doc.set(tournament.toJson());
    return tournament;
  }

  Future<void> joinTournament(String tournamentId, String uid) async {
    await _tournaments.doc(tournamentId).update({
      'participantUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<Tournament?> getTournament(String tournamentId) async {
    final doc = await _tournaments.doc(tournamentId).get();
    if (!doc.exists) return null;
    return Tournament.fromJson(doc.data()!);
  }

  Stream<List<Tournament>> tournamentsStream() {
    return _tournaments
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Tournament.fromJson(d.data())).toList());
  }

  Stream<List<TournamentMatch>> matchesStream(String tournamentId) {
    return _matchesOf(tournamentId)
        .orderBy('round')
        .snapshots()
        .map(
          (s) => s.docs.map((d) => TournamentMatch.fromJson(d.data())).toList(),
        );
  }

  /// 現在の参加者リストから1回戦のブラケットを生成し、トーナメントを
  /// `active`にする。シングルエリミネーションのみ対応。
  Future<void> startTournament(
    String tournamentId,
    Map<String, String> displayNames,
  ) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) return;
    if (tournament.format != 'single_elimination') {
      throw UnimplementedError(
        '${tournament.format} bracket generation is not implemented yet',
      );
    }
    if (!tournament.isUpcoming) return;

    final participants = List<String>.from(tournament.participantUids)
      ..shuffle(Random());
    final matches = _pairRound(
      participants,
      tournamentId: tournamentId,
      round: 1,
      displayNames: displayNames,
    );

    final batch = _firestore.batch();
    for (final m in matches) {
      batch.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
    }
    batch.update(_tournaments.doc(tournamentId), {'status': 'active'});
    await batch.commit();
    await _notifyMatches(matches);
  }

  List<TournamentMatch> _pairRound(
    List<String> uids, {
    required String tournamentId,
    required int round,
    required Map<String, String> displayNames,
  }) {
    final matches = <TournamentMatch>[];
    for (var i = 0; i < uids.length; i += 2) {
      final p1 = uids[i];
      final p2 = i + 1 < uids.length ? uids[i + 1] : null;
      final isBye = p2 == null;
      matches.add(
        TournamentMatch(
          id: '${tournamentId}_r${round}_m${matches.length}',
          tournamentId: tournamentId,
          player1Uid: p1,
          player1DisplayName: displayNames[p1],
          player2Uid: p2,
          player2DisplayName: p2 != null ? displayNames[p2] : null,
          round: round,
          // 不戦勝は1人残ったプレイヤーの自動勝利。
          winnerUid: isBye ? p1 : null,
          status: isBye ? 'completed' : 'pending',
          scheduledAt: DateTime.now(),
          completedAt: isBye ? DateTime.now() : null,
        ),
      );
    }
    return matches;
  }

  Future<void> _notifyMatches(List<TournamentMatch> matches) async {
    final notifications = _notifications;
    if (notifications == null) return;
    for (final m in matches) {
      if (m.isBye) continue;
      for (final uid in [m.player1Uid, m.player2Uid]) {
        if (uid == null) continue;
        await notifications.send(
          uid: uid,
          title: 'トーナメントの対戦相手が決まりました',
          body: '${m.round}回戦のペアリングが確定しました',
          type: 'tournament_match',
          data: {'tournamentId': m.tournamentId, 'matchId': m.id},
        );
      }
    }
  }

  /// [matchId]の勝者を[winnerUid]として記録し、現在のラウンドの全試合が
  /// 完了していれば次ラウンドへ自動進行する。
  Future<void> recordMatchResult(
    String tournamentId,
    String matchId,
    String winnerUid,
    Map<String, String> displayNames,
  ) async {
    await _matchesOf(tournamentId).doc(matchId).update({
      'winnerUid': winnerUid,
      'status': 'completed',
      'completedAt': DateTime.now().toIso8601String(),
    });
    await _advanceRoundIfComplete(tournamentId, displayNames);
  }

  /// トランザクション内で読み取り・判定・書き込みを行うため、2つの試合
  /// がほぼ同時に完了しても次ラウンドが二重生成されない
  /// （`lastAdvancedRound`が既に進んでいれば何もしない）。
  Future<void> _advanceRoundIfComplete(
    String tournamentId,
    Map<String, String> displayNames,
  ) async {
    await _firestore.runTransaction((tx) async {
      final tournamentRef = _tournaments.doc(tournamentId);
      final tournamentSnap = await tx.get(tournamentRef);
      if (!tournamentSnap.exists) return;
      final tournament = Tournament.fromJson(tournamentSnap.data()!);
      if (!tournament.isActive) return;

      final matchesSnap = await _matchesOf(tournamentId).get();
      final matches = matchesSnap.docs
          .map((d) => TournamentMatch.fromJson(d.data()))
          .toList();
      final currentRound = matches.map((m) => m.round).reduce(max);
      if (currentRound <= tournament.lastAdvancedRound) return;

      final roundMatches = matches.where((m) => m.round == currentRound);
      if (roundMatches.any((m) => !m.isCompleted)) return;

      final winners = roundMatches.map((m) => m.winnerUid!).toList();
      if (winners.length == 1) {
        tx.update(tournamentRef, {
          'status': 'completed',
          'winnerId': winners.first,
          'lastAdvancedRound': currentRound,
        });
        return;
      }

      final nextMatches = _pairRound(
        winners,
        tournamentId: tournamentId,
        round: currentRound + 1,
        displayNames: displayNames,
      );
      for (final m in nextMatches) {
        tx.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
      }
      tx.update(tournamentRef, {'lastAdvancedRound': currentRound});
    });
  }
}
