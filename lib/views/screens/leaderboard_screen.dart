import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';

/// ランキング画面。komovia_shogiの`LeaderboardScreen`と同じ役割
/// （all-time/ratingのトップ50を表示する）。
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(topLeaderboardEntriesProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('ランキング')),
      body: entries.isEmpty
          ? const Center(child: Text('まだランキングに登録された対局者がいません'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(e.displayName),
                  trailing: Text('${e.rating}'),
                  subtitle: Text(
                    '${e.wins}/${e.gamesPlayed} 勝 (${(e.winRate * 100).toStringAsFixed(0)}%)',
                  ),
                );
              },
            ),
    );
  }
}
