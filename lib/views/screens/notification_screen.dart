import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'reversia_pvp_game_screen.dart';

/// 通知一覧画面。komovia_shogiの`NotificationScreen`と同じ役割。
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsStreamProvider(uid)).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: notifications.isEmpty
          ? const Center(child: Text('通知はありません'))
          : ListView(
              children: notifications
                  .map(
                    (n) => ListTile(
                      leading: Icon(
                        n.isRead ? Icons.notifications_none : Icons.notifications,
                      ),
                      title: Text(n.title),
                      subtitle: Text(n.body),
                      onTap: () {
                        ref.read(markNotificationReadProvider)(uid, n.id);
                        // pvp_challenge通知: 新しいPvP対局が始まったことの
                        // 通知（ReversiaMatchingScreen._startGame/
                        // ReversiaChallengeScreen参照）。タップで該当の
                        // ReversiaPvpGameScreenへ遷移する。
                        final gameId = n.type == 'pvp_challenge'
                            ? (n.data?['gameId'] as String?)
                            : null;
                        if (gameId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReversiaPvpGameScreen(gameId: gameId),
                            ),
                          );
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
