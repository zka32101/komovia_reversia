import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';

/// 「成長の記録」画面 - komovia_shogi/komovia_goの`GrowthScreen`と同じ役割
/// （reversia向けに日本語化）。負けが続いても心が折れず遊び続けられ、
/// 着実な成長を実感できるというシリーズ共通のコンセプトに沿って、
/// レーティング・対局数・勝率と、常に前向きな一言コメントを表示する
/// （まだ対局記録の推移を保存していないため、推移グラフは含めない -
/// komovia_shogiの同画面と同じ割り切り）。project-015の
/// `engine/statistics.dart`（`GameStatistics`）の移植漏れだった引き分け
/// 数・現在の連勝・最長連勝も`ReversiaGameStats`から追加表示する。
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entryAsync = ref.watch(myLeaderboardEntryProvider);
    final statsAsync = ref.watch(myReversiaGameStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.growthTitle)),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.growthLoadFailedMessage(error.toString()))),
        data: (entry) {
          if (entry == null || entry.gamesPlayed == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.growthNoRecordsMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final stats = statsAsync.value;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                icon: Icons.military_tech,
                label: l10n.growthCurrentRatingLabel,
                value: '${entry.rating}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.sports_esports,
                      label: l10n.growthGamesPlayedLabel,
                      value: '${entry.gamesPlayed}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events,
                      label: l10n.growthWinRateLabel,
                      value: '${(entry.winRate * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
              if (stats != null && stats.totalGames > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.handshake_outlined,
                        label: l10n.growthDrawsLabel,
                        value: '${stats.draws}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department,
                        label: l10n.growthCurrentStreakLabel,
                        value: '${stats.currentWinStreak}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.whatshot,
                        label: l10n.growthLongestStreakLabel,
                        value: '${stats.longestWinStreak}',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _encouragement(l10n, entry.gamesPlayed, entry.winRate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 勝率がどうであれ、常に前向きなメッセージを返す - 負けが続いても
  /// 遊び続けてもらうという、シリーズ共通のコンセプトのため、
  /// 「もっと頑張れ」のような否定的な表現は使わない。
  String _encouragement(AppLocalizations l10n, int gamesPlayed, double winRate) {
    if (gamesPlayed < 5) {
      return l10n.growthEncouragementBeginner;
    }
    if (winRate >= 0.6) {
      return l10n.growthEncouragementGoodWinRate;
    }
    return l10n.growthEncouragementKeepGoing(gamesPlayed);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
