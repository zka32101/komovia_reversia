import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'tournament_bracket_screen.dart';

/// トーナメント一覧画面 - komovia_shogiの`TournamentScreen`と同じ役割
/// （reversia向けに日本語化）。
class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tournaments = ref.watch(tournamentsStreamProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTournamentTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: l10n.tournamentCreateTooltip,
        child: const Icon(Icons.add),
      ),
      body: tournaments.isEmpty
          ? Center(child: Text(l10n.tournamentEmptyMessage))
          : ListView(
              children: tournaments.map((t) {
                final joined = t.participantUids.contains(uid);
                return ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    '${t.format} · ${t.status} · ${t.participantUids.length}/${t.maxParticipants}',
                  ),
                  trailing: !joined && t.isUpcoming && !t.isFull
                      ? TextButton(
                          onPressed: () =>
                              ref.read(joinTournamentProvider)(t.id, uid),
                          child: Text(l10n.tournamentJoinButton),
                        )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TournamentBracketScreen(
                        tournamentId: t.id,
                        uid: uid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    var format = 'single_elimination';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.tournamentCreateTooltip),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.tournamentNameLabel),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: format,
                decoration: InputDecoration(labelText: l10n.tournamentFormatLabel),
                items: [
                  DropdownMenuItem(
                    value: 'single_elimination',
                    child: Text(l10n.tournamentFormatSingleElimination),
                  ),
                  DropdownMenuItem(
                    value: 'round_robin',
                    child: Text(l10n.tournamentFormatRoundRobin),
                  ),
                  DropdownMenuItem(
                    value: 'swiss',
                    child: Text(l10n.tournamentFormatSwiss),
                  ),
                ],
                onChanged: (v) => setState(() => format = v ?? format),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancelButton),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final now = DateTime.now();
                  ref.read(createTournamentProvider)(
                    name: name,
                    description: '',
                    createdBy: uid,
                    startDate: now,
                    endDate: now.add(const Duration(days: 7)),
                    format: format,
                  );
                }
                Navigator.pop(ctx);
              },
              child: Text(l10n.tournamentCreateButton),
            ),
          ],
        ),
      ),
    );
  }
}
