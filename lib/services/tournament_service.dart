import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import 'notification_service.dart';

/// トーナメント作成/参加/ブラケット進行 - komovia_shogiの
/// `tournament_service.dart`と同じ役割（komovia_coreの共通モデル
/// `Tournament`/`TournamentMatch`を使用）。シングルエリミネーション
/// （奇数人数の不戦勝対応含む）に加え、komovia_goの`tournament_service.dart`
/// から移植したround_robin（サークル法で全節を一度に生成、優勝は勝ち数
/// 最多者）とswiss（総ラウンド数をmax(3, ceil(log2(n)))で自動計算し、
/// 各ラウンドを勝ち数順の貪欲ペアリングで生成）にも対応する。
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

  /// 現在の参加者リストからブラケット/スケジュールを生成し、トーナメントを
  /// `active`にする。
  Future<void> startTournament(
    String tournamentId,
    Map<String, String> displayNames,
  ) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) return;
    if (!tournament.isUpcoming) return;

    if (tournament.format == 'round_robin') {
      final schedule = _roundRobinPairings(tournament.participantUids);
      final matches = <TournamentMatch>[];
      final batch = _firestore.batch();
      for (var i = 0; i < schedule.length; i++) {
        final round = i + 1;
        for (final pair in schedule[i]) {
          final m = _buildMatch(
            tournamentId: tournamentId,
            round: round,
            player1Uid: pair.$1,
            player2Uid: pair.$2,
            displayNames: displayNames,
          );
          batch.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
          matches.add(m);
        }
      }
      batch.update(_tournaments.doc(tournamentId), {'status': 'active'});
      await batch.commit();
      await _notifyMatches(matches);
      return;
    }

    if (tournament.format == 'swiss') {
      final totalRounds = _computeSwissTotalRounds(
        tournament.participantUids.length,
      );
      final shuffled = List<String>.from(tournament.participantUids)
        ..shuffle(Random());
      final (pairs, byeUid) = _swissPairings(shuffled, const []);
      final matches = _writeSwissRound(
        tournamentId: tournamentId,
        round: 1,
        pairs: pairs,
        byeUid: byeUid,
        displayNames: displayNames,
      );
      final batch = _firestore.batch();
      for (final m in matches) {
        batch.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
      }
      batch.update(_tournaments.doc(tournamentId), {
        'status': 'active',
        'totalRounds': totalRounds,
      });
      await batch.commit();
      await _notifyMatches(matches);
      return;
    }

    if (tournament.format != 'single_elimination') {
      throw UnimplementedError(
        '${tournament.format} bracket generation is not implemented yet',
      );
    }

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

  TournamentMatch _buildMatch({
    required String tournamentId,
    required int round,
    required String player1Uid,
    String? player2Uid,
    required Map<String, String> displayNames,
    bool isBye = false,
  }) {
    return TournamentMatch(
      id: _matchesOf(tournamentId).doc().id,
      tournamentId: tournamentId,
      player1Uid: player1Uid,
      player1DisplayName: displayNames[player1Uid],
      player2Uid: player2Uid,
      player2DisplayName: player2Uid != null ? displayNames[player2Uid] : null,
      round: round,
      winnerUid: isBye ? player1Uid : null,
      status: isBye ? 'completed' : 'pending',
      scheduledAt: DateTime.now(),
      completedAt: isBye ? DateTime.now() : null,
    );
  }

  /// 総当たり戦の対戦カードをサークル法で組む。先頭を固定し、残りを1つずつ
  /// 回転させることで、全員が互いに一度ずつ当たる組み合わせを作る。
  /// 参加者が奇数の場合はnullの空き枠を1つ加え（その節はその相手が不戦休み
  /// - 試合ドキュメント自体は作らない）、偶数ならn-1節、奇数ならn節になる。
  List<List<(String, String)>> _roundRobinPairings(List<String> uids) {
    final players = List<String?>.from(uids);
    if (players.length.isOdd) players.add(null);
    final n = players.length;
    final rounds = <List<(String, String)>>[];

    for (var r = 0; r < n - 1; r++) {
      final roundPairs = <(String, String)>[];
      for (var i = 0; i < n ~/ 2; i++) {
        final a = players[i];
        final b = players[n - 1 - i];
        if (a != null && b != null) roundPairs.add((a, b));
      }
      rounds.add(roundPairs);
      final last = players.removeLast();
      players.insert(1, last);
    }
    return rounds;
  }

  /// swiss形式の総ラウンド数。全参加者を明確に順位付けするための標準的な
  /// 目安（ceil(log2(n))）に、対局数が少なすぎて順位がほぼ決まらないのを
  /// 避けるための最低3ラウンドを組み合わせる。
  int _computeSwissTotalRounds(int participantCount) {
    if (participantCount <= 1) return 1;
    final byLog = (log(participantCount) / log(2)).ceil();
    return max(3, byLog);
  }

  String _swissPairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }

  /// swiss形式のペアリング（貪欲法）。現在の勝ち数が多い順（同数はuid昇順）
  /// に並べ、まだ対戦していない相手の中から先頭に近い人と組ませていく -
  /// 本格的なDutch systemほど最適ではないが、round_robinの簡易タイブレーク
  /// と同じ精神で、実用上十分な近似として採用する。参加者が奇数なら、
  /// 最後に残った1人（＝現在最下位）が不戦勝(bye)になる。
  (List<(String, String)>, String?) _swissPairings(
    List<String> allUids,
    List<TournamentMatch> matchesSoFar,
  ) {
    final wins = <String, int>{for (final uid in allUids) uid: 0};
    final playedPairs = <String>{};
    for (final m in matchesSoFar) {
      if (m.winnerUid != null) {
        wins[m.winnerUid!] = (wins[m.winnerUid!] ?? 0) + 1;
      }
      if (m.player1Uid != null && m.player2Uid != null) {
        playedPairs.add(_swissPairKey(m.player1Uid!, m.player2Uid!));
      }
    }

    final sorted = List<String>.from(allUids)
      ..sort((a, b) {
        final winsCompare = (wins[b] ?? 0).compareTo(wins[a] ?? 0);
        return winsCompare != 0 ? winsCompare : a.compareTo(b);
      });

    final unpaired = List<String>.from(sorted);
    final pairs = <(String, String)>[];
    while (unpaired.length > 1) {
      final a = unpaired.removeAt(0);
      final idx =
          unpaired.indexWhere((b) => !playedPairs.contains(_swissPairKey(a, b)));
      final b = unpaired.removeAt(idx == -1 ? 0 : idx);
      pairs.add((a, b));
    }

    return (pairs, unpaired.isNotEmpty ? unpaired.first : null);
  }

  List<TournamentMatch> _writeSwissRound({
    required String tournamentId,
    required int round,
    required List<(String, String)> pairs,
    required String? byeUid,
    required Map<String, String> displayNames,
  }) {
    final matches = <TournamentMatch>[];
    for (final pair in pairs) {
      matches.add(_buildMatch(
        tournamentId: tournamentId,
        round: round,
        player1Uid: pair.$1,
        player2Uid: pair.$2,
        displayNames: displayNames,
      ));
    }
    if (byeUid != null) {
      matches.add(_buildMatch(
        tournamentId: tournamentId,
        round: round,
        player1Uid: byeUid,
        displayNames: displayNames,
        isBye: true,
      ));
    }
    return matches;
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

  /// [matchId]の勝者を[winnerUid]として記録する。
  /// - single_elimination: 現在のラウンドの全試合が完了していれば次ラウンド
  ///   へ自動進行する。
  /// - round_robin: 全節の全試合が完了していれば、勝ち数最多者を優勝として
  ///   トーナメントを完了にする（全対戦カードは開始時に一度に生成済み）。
  /// - swiss: そのラウンドの全試合（不戦勝含む）が完了していれば、最終
  ///   ラウンドならトーナメントを完了、そうでなければ次ラウンドを生成する。
  Future<void> recordMatchResult(
    String tournamentId,
    String matchId,
    String winnerUid, [
    Map<String, String> displayNames = const {},
  ]) async {
    final matchDoc = await _matchesOf(tournamentId).doc(matchId).get();
    final round = (matchDoc.data()?['round'] as int?) ?? 1;

    await _matchesOf(tournamentId).doc(matchId).update({
      'winnerUid': winnerUid,
      'status': 'completed',
      'completedAt': DateTime.now().toIso8601String(),
    });

    // 呼び出し元(例: PvP対局終局時のフック)は、その対局の2人分の表示名
    // しか知らない場合がある。次ラウンドの組み合わせには、同ラウンドの
    // 他の試合の勝者の表示名も必要なため、既存の試合ドキュメントから
    // 分かる範囲で補完する（呼び出し元の値を優先）。
    final existingMatches = await _matchesOf(tournamentId).get();
    final mergedDisplayNames = <String, String>{
      for (final doc in existingMatches.docs)
        for (final m in [TournamentMatch.fromJson(doc.data())]) ...{
          if (m.player1Uid != null && m.player1DisplayName != null)
            m.player1Uid!: m.player1DisplayName!,
          if (m.player2Uid != null && m.player2DisplayName != null)
            m.player2Uid!: m.player2DisplayName!,
        },
      ...displayNames,
    };

    final tournament = await getTournament(tournamentId);
    if (tournament?.format == 'round_robin') {
      await _completeRoundRobinIfDone(tournamentId);
    } else if (tournament?.format == 'swiss') {
      await _advanceSwissRoundIfComplete(
        tournamentId,
        round,
        mergedDisplayNames,
      );
    } else {
      await _advanceRoundIfComplete(tournamentId, mergedDisplayNames);
    }
  }

  /// 完了済み試合の勝敗から勝ち数最多の参加者を求める（同数はuid昇順）。
  String? _computeStandingsChampion(List<TournamentMatch> matches) {
    final wins = <String, int>{};
    final participants = <String>{};
    for (final m in matches) {
      if (m.player1Uid != null) participants.add(m.player1Uid!);
      if (m.player2Uid != null) participants.add(m.player2Uid!);
      if (m.winnerUid != null) {
        wins[m.winnerUid!] = (wins[m.winnerUid!] ?? 0) + 1;
      }
    }
    if (participants.isEmpty) return null;
    final sorted = participants.toList()
      ..sort((a, b) {
        final winsCompare = (wins[b] ?? 0).compareTo(wins[a] ?? 0);
        return winsCompare != 0 ? winsCompare : a.compareTo(b);
      });
    return sorted.first;
  }

  /// 総当たり戦の全試合が完了していれば、勝ち数最多者を優勝としてトーナ
  /// メントを完了にする。トランザクション内で既にcompletedかどうかを
  /// 確認するため、複数の試合がほぼ同時に完了しても二重確定は起きない。
  Future<void> _completeRoundRobinIfDone(String tournamentId) async {
    await _firestore.runTransaction((tx) async {
      final tournamentRef = _tournaments.doc(tournamentId);
      final tournamentSnap = await tx.get(tournamentRef);
      if (!tournamentSnap.exists) return;
      final tournament = Tournament.fromJson(tournamentSnap.data()!);
      if (tournament.status == 'completed') return;

      final matchesSnap = await _matchesOf(tournamentId).get();
      final matches = matchesSnap.docs
          .map((d) => TournamentMatch.fromJson(d.data()))
          .toList();
      if (matches.any((m) => !m.isCompleted)) return;

      final championUid = _computeStandingsChampion(matches);
      tx.update(tournamentRef, {
        'status': 'completed',
        'winnerId': championUid,
      });
    });
  }

  /// 指定ラウンドの全試合（不戦勝も含む）が完了していれば、swissの次ラウンド
  /// を生成するか、最終ラウンドなら順位表から優勝を確定してトーナメントを
  /// 完了にする。single_eliminationの_advanceRoundIfCompleteと同じく、
  /// `Tournament.lastAdvancedRound`をトランザクション内でチェック＆更新
  /// することで、複数試合がほぼ同時に完了しても次ラウンドを二重生成しない。
  Future<void> _advanceSwissRoundIfComplete(
    String tournamentId,
    int round,
    Map<String, String> displayNames,
  ) async {
    await _firestore.runTransaction((tx) async {
      final tournamentRef = _tournaments.doc(tournamentId);
      final tournamentSnap = await tx.get(tournamentRef);
      if (!tournamentSnap.exists) return;
      final tournament = Tournament.fromJson(tournamentSnap.data()!);
      if (!tournament.isActive) return;
      if (tournament.lastAdvancedRound >= round) return;

      final matchesSnap = await _matchesOf(tournamentId).get();
      final matches = matchesSnap.docs
          .map((d) => TournamentMatch.fromJson(d.data()))
          .toList();

      final roundMatches = matches.where((m) => m.round == round);
      if (roundMatches.isEmpty || roundMatches.any((m) => !m.isCompleted)) {
        return;
      }

      if (round >= tournament.totalRounds) {
        final championUid = _computeStandingsChampion(matches);
        tx.update(tournamentRef, {
          'status': 'completed',
          'winnerId': championUid,
          'lastAdvancedRound': round,
        });
        return;
      }

      final allPlayerUids = <String>{
        for (final m in matches) ...[
          if (m.player1Uid != null) m.player1Uid!,
          if (m.player2Uid != null) m.player2Uid!,
        ],
      }.toList();
      final (pairs, byeUid) = _swissPairings(allPlayerUids, matches);
      final nextMatches = _writeSwissRound(
        tournamentId: tournamentId,
        round: round + 1,
        pairs: pairs,
        byeUid: byeUid,
        displayNames: displayNames,
      );
      for (final m in nextMatches) {
        tx.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
      }
      tx.update(tournamentRef, {'lastAdvancedRound': round});
    });
  }

  /// 総当たり戦/swiss形式共通の順位表。勝ち数の多い順（同数はuid昇順の
  /// 簡易タイブレーク - 対戦成績・得失点差などの本格的なタイブレークは
  /// 未実装、既知の制約）。
  Future<List<TournamentStandingEntry>> getStandings(String tournamentId) async {
    final matchesSnap = await _matchesOf(tournamentId).get();
    final matches = matchesSnap.docs
        .map((d) => TournamentMatch.fromJson(d.data()))
        .toList();

    final wins = <String, int>{};
    final losses = <String, int>{};
    final displayNames = <String, String>{};
    for (final m in matches) {
      if (m.player1Uid != null) {
        displayNames[m.player1Uid!] = m.player1DisplayName ?? m.player1Uid!;
      }
      if (m.player2Uid != null) {
        displayNames[m.player2Uid!] = m.player2DisplayName ?? m.player2Uid!;
      }
      if (!m.isCompleted || m.winnerUid == null) continue;
      wins[m.winnerUid!] = (wins[m.winnerUid!] ?? 0) + 1;
      final loserUid =
          m.winnerUid == m.player1Uid ? m.player2Uid : m.player1Uid;
      if (loserUid != null) {
        losses[loserUid] = (losses[loserUid] ?? 0) + 1;
      }
    }

    final entries = displayNames.entries
        .map((e) => TournamentStandingEntry(
              uid: e.key,
              displayName: e.value,
              wins: wins[e.key] ?? 0,
              losses: losses[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) {
        final winsCompare = b.wins.compareTo(a.wins);
        return winsCompare != 0 ? winsCompare : a.uid.compareTo(b.uid);
      });
    return entries;
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
