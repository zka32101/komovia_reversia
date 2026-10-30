import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/achievement_service.dart';
import '../../viewmodels/index.dart';

/// 実績一覧画面。解除済みは金色のバッジ、未解除はロック表示+進捗バー。
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final progressAsync = ref.watch(achievementProgressProvider(uid));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: progressAsync.when(
        data: (progress) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: progress.length,
          itemBuilder: (context, index) => _AchievementCard(progress: progress[index]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            l10n.commonErrorMessage(err.toString()),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final def = progress.definition;
    final unlocked = progress.isUnlocked;

    return Card(
      color: unlocked ? Colors.amber.withOpacity(0.15) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  def.icon,
                  style: TextStyle(
                    fontSize: 40,
                    color: unlocked ? null : Colors.grey.withOpacity(0.4),
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(Icons.lock, size: 16, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              def.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: unlocked ? Colors.amber[800] : null,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              def.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (!unlocked)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress.progressPercent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.currentValue} / ${def.targetValue}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            else
              const Icon(Icons.check_circle, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}
