import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'reversia_pvp_game_screen.dart';

/// トーナメントブラケット画面 - komovia_shogiの`TournamentBracketScreen`
/// と同じ役割（reversia向けに日本語化）。試合結果は自己申告ではなく、
/// 実際に`ReversiaPvpGameScreen`で対局した結果が
/// `createTournamentReversiaGameProvider`/対局終局フックを通じて自動的に
/// 反映される（komovia_goの`createGameForTournamentMatch`/
/// `_onGameFinished`と同じ役割）。
class TournamentBracketScreen extends ConsumerStatefulWidget {
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
  ConsumerState<TournamentBracketScreen> createState() =>
      _TournamentBracketScreenState();
}

class _TournamentBracketScreenState
    extends ConsumerState<TournamentBracketScreen> {
  bool _isCreatingGame = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final matches = ref
            .watch(tournamentMatchesStreamProvider(widget.tournamentId))
            .value ??
        [];
    final tournaments = ref.watch(tournamentsStreamProvider).value ?? [];
    final tournament =
        tournaments.where((t) => t.id == widget.tournamentId).isEmpty
            ? null
            : tournaments.firstWhere((t) => t.id == widget.tournamentId);

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
    displayNames[widget.uid] = widget.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament?.name ?? l10n.homeTournamentTitle),
        actions: [
          if (tournament != null && tournament.format != 'single_elimination')
            IconButton(
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: l10n.tournamentStandingsTooltip,
              onPressed: () => _showStandings(context),
            ),
        ],
      ),
      floatingActionButton: tournament != null && tournament.isUpcoming
          ? FloatingActionButton.extended(
              onPressed: () => ref.read(startTournamentProvider)(
                widget.tournamentId,
                displayNames,
              ),
              label: Text(l10n.tournamentStartButton),
              icon: const Icon(Icons.play_arrow),
            )
          : null,
      body: byRound.isEmpty
          ? Center(child: Text(l10n.tournamentBracketEmptyMessage))
          : ListView(
              children: byRound.entries.map((entry) {
                return ExpansionTile(
                  title: Text(l10n.tournamentRoundLabel(entry.key)),
                  initiallyExpanded: true,
                  children: entry.value
                      .map<Widget>((m) => _buildMatchTile(m, displayNames, l10n))
                      .toList(),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMatchTile(
    TournamentMatch m,
    Map<String, String> displayNames,
    AppLocalizations l10n,
  ) {
    final isMyMatch = m.player1Uid == widget.uid || m.player2Uid == widget.uid;
    final canStart = isMyMatch &&
        m.isPending &&
        !m.isBye &&
        m.gameId == null;

    return ListTile(
      title: Text(
        '${m.player1DisplayName ?? l10n.tournamentByeLabel} vs '
        '${m.player2DisplayName ?? l10n.tournamentByeLabel}',
      ),
      subtitle: Text(
        m.isCompleted
            ? l10n.tournamentWinnerLabel(displayNames[m.winnerUid] ?? m.winnerUid ?? '')
            : m.status,
      ),
      trailing: m.gameId != null
          ? TextButton(
              onPressed: () => _openGame(m.gameId!),
              child: Text(l10n.tournamentViewGameButton),
            )
          : canStart
              ? TextButton(
                  onPressed:
                      _isCreatingGame ? null : () => _startMatch(m, displayNames),
                  child: Text(l10n.tournamentStartMatchButton),
                )
              : null,
    );
  }

  Future<void> _startMatch(
    TournamentMatch m,
    Map<String, String> displayNames,
  ) async {
    setState(() => _isCreatingGame = true);
    try {
      final opponentUid =
          m.player1Uid == widget.uid ? m.player2Uid! : m.player1Uid!;
      final opponentName = (m.player1Uid == widget.uid
              ? m.player2DisplayName
              : m.player1DisplayName) ??
          'Player';

      // UIDの辞書順が小さい方を先手にする（両対局者が同じ結果になるようにする）。
      final amIFirst = widget.uid.compareTo(opponentUid) < 0;
      final gameId = await ref.read(createTournamentReversiaGameProvider)(
        tournamentId: widget.tournamentId,
        matchId: m.id,
        firstUid: amIFirst ? widget.uid : opponentUid,
        firstDisplayName: amIFirst ? widget.displayName : opponentName,
        secondUid: amIFirst ? opponentUid : widget.uid,
        secondDisplayName: amIFirst ? opponentName : widget.displayName,
      );

      if (!mounted) return;
      _openGame(gameId);
    } finally {
      if (mounted) setState(() => _isCreatingGame = false);
    }
  }

  void _openGame(String gameId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReversiaPvpGameScreen(gameId: gameId),
      ),
    );
  }

  Future<void> _showStandings(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final standings = await ref
        .read(tournamentStandingsProvider(widget.tournamentId).future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tournamentStandingsTooltip),
        content: SizedBox(
          width: double.maxFinite,
          child: standings.isEmpty
              ? Text(l10n.tournamentStandingsEmptyMessage)
              : ListView(
                  shrinkWrap: true,
                  children: standings.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final entry = e.value;
                    return ListTile(
                      leading: Text(l10n.tournamentRankLabel(rank)),
                      title: Text(entry.displayName),
                      trailing: Text(
                        l10n.tournamentWinLossLabel(entry.wins, entry.losses),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }
}
