import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final tournaments = ref.watch(tournamentsStreamProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('トーナメント')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: 'トーナメントを作成',
        child: const Icon(Icons.add),
      ),
      body: tournaments.isEmpty
          ? const Center(child: Text('まだトーナメントはありません'))
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
                          child: const Text('参加する'),
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
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('トーナメントを作成'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '名前'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
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
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }
}
