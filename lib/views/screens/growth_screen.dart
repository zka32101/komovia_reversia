import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';

/// 「成長の記録」画面 - komovia_shogi/komovia_goの`GrowthScreen`と同じ役割
/// （reversia向けに日本語化）。負けが続いても心が折れず遊び続けられ、
/// 着実な成長を実感できるというシリーズ共通のコンセプトに沿って、
/// レーティング・対局数・勝率と、常に前向きな一言コメントを表示する
/// （まだ対局記録の推移を保存していないため、推移グラフは含めない -
/// komovia_shogiの同画面と同じ割り切り）。
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(myLeaderboardEntryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('成長の記録')),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('読み込みに失敗しました: $error')),
        data: (entry) {
          if (entry == null || entry.gamesPlayed == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'まだ対局記録がありません。\nAIと対局すると、ここに成長の記録が表示されます。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                icon: Icons.military_tech,
                label: '現在のレーティング',
                value: '${entry.rating}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.sports_esports,
                      label: '対局数',
                      value: '${entry.gamesPlayed}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events,
                      label: '勝率',
                      value: '${(entry.winRate * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _encouragement(entry.gamesPlayed, entry.winRate),
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
  String _encouragement(int gamesPlayed, double winRate) {
    if (gamesPlayed < 5) {
      return 'ここからが始まりです。対局を重ねるごとに、着実に力がついていきます。';
    }
    if (winRate >= 0.6) {
      return '素晴らしい勝率です！この調子で指し続けましょう。';
    }
    return '$gamesPlayed局、よく指し続けています。一局ごとの経験が、確かな力になっています。';
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
