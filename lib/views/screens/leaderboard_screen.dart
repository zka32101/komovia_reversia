import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';

/// ランキング画面。komovia_shogiの`LeaderboardScreen`と同じ役割
/// （all-time/ratingのトップ50を表示する）。
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entries = ref.watch(topLeaderboardEntriesProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderboardTitle)),
      body: entries.isEmpty
          ? Center(child: Text(l10n.leaderboardEmptyMessage))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(e.displayName),
                  trailing: Text('${e.rating}'),
                  subtitle: Text(
                    l10n.leaderboardWinsSubtitle(
                      e.wins,
                      e.gamesPlayed,
                      (e.winRate * 100).toStringAsFixed(0),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
