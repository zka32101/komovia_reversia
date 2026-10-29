import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../viewmodels/index.dart';

/// トーナメントブラケット画面 - komovia_shogiの`TournamentBracketScreen`
/// と同じ役割（reversia向けに日本語化）。「勝ちを報告する」は自分自身の
/// 試合結果をそのまま報告する簡易方式（実際のPvP対局との紐付けは未実装
/// - GoEnの本家実装でもこの段階ではまだ対応していなかった範囲）。
class TournamentBracketScreen extends ConsumerWidget {
  const TournamentBracketScreen({
    super.key,
    required this.tournamentId,
    required this.uid,
    required this.displayName,
  });

  final String tournamentId;
  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches =
        ref.watch(tournamentMatchesStreamProvider(tournamentId)).value ?? [];
    final tournaments = ref.watch(tournamentsStreamProvider).value ?? [];
    final tournament = tournaments.where((t) => t.id == tournamentId).isEmpty
        ? null
        : tournaments.firstWhere((t) => t.id == tournamentId);

    final byRound = <int, List<TournamentMatch>>{};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }

    final displayNames = <String, String>{};
    for (final m in matches) {
      if (m.player1Uid != null) {
        displayNames[m.player1Uid!] = m.player1DisplayName ?? '';
      }
      if (m.player2Uid != null) {
        displayNames[m.player2Uid!] = m.player2DisplayName ?? '';
      }
    }
    displayNames[uid] = displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament?.name ?? 'トーナメント'),
        actions: [
          if (tournament != null && tournament.format != 'single_elimination')
            IconButton(
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: '順位表',
              onPressed: () => _showStandings(context, ref),
            ),
        ],
      ),
      floatingActionButton: tournament != null && tournament.isUpcoming
          ? FloatingActionButton.extended(
              onPressed: () =>
                  ref.read(startTournamentProvider)(tournamentId, displayNames),
              label: const Text('開始する'),
              icon: const Icon(Icons.play_arrow),
            )
          : null,
      body: byRound.isEmpty
          ? const Center(child: Text('まだブラケットは生成されていません'))
          : ListView(
              children: byRound.entries.map((entry) {
                return ExpansionTile(
                  title: Text('${entry.key}回戦'),
                  initiallyExpanded: true,
                  children: entry.value.map<Widget>((m) {
                    final isMyMatch = (m.player1Uid == uid || m.player2Uid == uid) &&
                        !m.isCompleted &&
                        !m.isBye;
                    return ListTile(
                      title: Text(
                        '${m.player1DisplayName ?? "不戦勝"} vs ${m.player2DisplayName ?? "不戦勝"}',
                      ),
                      subtitle: Text(
                        m.isCompleted
                            ? '勝者: ${displayNames[m.winnerUid] ?? m.winnerUid}'
                            : m.status,
                      ),
                      trailing: isMyMatch
                          ? TextButton(
                              onPressed: () => ref.read(recordMatchResultProvider)(
                                tournamentId,
                                m.id,
                                uid,
                                displayNames,
                              ),
                              child: const Text('勝ちを報告する'),
                            )
                          : null,
                    );
                  }).toList(),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _showStandings(BuildContext context, WidgetRef ref) async {
    final standings =
        await ref.read(tournamentStandingsProvider(tournamentId).future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('順位表'),
        content: SizedBox(
          width: double.maxFinite,
          child: standings.isEmpty
              ? const Text('まだ試合結果がありません')
              : ListView(
                  shrinkWrap: true,
                  children: standings.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final entry = e.value;
                    return ListTile(
                      leading: Text('$rank位'),
                      title: Text(entry.displayName),
                      trailing: Text('${entry.wins}勝${entry.losses}敗'),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
