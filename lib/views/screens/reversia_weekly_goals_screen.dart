import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import '../../models/reversia_weekly_progress.dart';
import '../../viewmodels/index.dart';

/// 週替わりの目標画面 - project-015の`weekly_goals_screen.dart`の
/// 移植漏れ分（ポイント/バッジ報酬は無い最小構成、`ReversiaWeeklyGoal`
/// 参照）。AI対局・パズルの既存のプレイに応じて進捗が自動で更新される。
class ReversiaWeeklyGoalsScreen extends ConsumerWidget {
  const ReversiaWeeklyGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(myReversiaWeeklyProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('今週の目標')),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('読み込みに失敗しました: $error')),
        data: (progress) {
          final p = progress ?? ReversiaWeeklyProgress.initial;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final goal in ReversiaWeeklyGoal.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GoalCard(goal: goal, progress: p),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.progress});

  final ReversiaWeeklyGoal goal;
  final ReversiaWeeklyProgress progress;

  @override
  Widget build(BuildContext context) {
    final completed = goal.isCompletedBy(progress);
    final current = goal.valueOf(progress);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(goal.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (completed)
                  const Icon(Icons.check_circle, color: Colors.green)
                else
                  Text('$current / ${goal.target}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(goal.description),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: goal.progressOf(progress)),
          ],
        ),
      ),
    );
  }
}
