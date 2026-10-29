import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

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
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '通知設定',
            onPressed: () => _showPreferenceDialog(context, ref),
          ),
        ],
      ),
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

  Future<void> _showPreferenceDialog(BuildContext context, WidgetRef ref) async {
    final preference = await ref.read(notificationPreferenceProvider(uid).future);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _NotificationPreferenceDialog(
        preference: preference,
        onSave: (updated) async {
          await ref.read(saveNotificationPreferenceProvider)(uid, updated);
          ref.invalidate(notificationPreferenceProvider(uid));
        },
      ),
    );
  }
}

class _NotificationPreferenceDialog extends StatefulWidget {
  const _NotificationPreferenceDialog({
    required this.preference,
    required this.onSave,
  });

  final NotificationPreference preference;
  final Future<void> Function(NotificationPreference) onSave;

  @override
  State<_NotificationPreferenceDialog> createState() =>
      _NotificationPreferenceDialogState();
}

class _NotificationPreferenceDialogState
    extends State<_NotificationPreferenceDialog> {
  late bool _allNotifications;
  late bool _friendRequests;
  late bool _gameInvitations;
  late bool _tournamentUpdates;
  late bool _achievements;

  @override
  void initState() {
    super.initState();
    _allNotifications = widget.preference.allNotifications;
    _friendRequests = widget.preference.friendRequests;
    _gameInvitations = widget.preference.gameInvitations;
    _tournamentUpdates = widget.preference.tournamentUpdates;
    _achievements = widget.preference.achievements;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('通知設定'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSwitch(
              'すべての通知',
              _allNotifications,
              (v) => setState(() => _allNotifications = v),
            ),
            _buildSwitch(
              'フレンド申請',
              _friendRequests,
              (v) => setState(() => _friendRequests = v),
            ),
            _buildSwitch(
              '対局の招待',
              _gameInvitations,
              (v) => setState(() => _gameInvitations = v),
            ),
            _buildSwitch(
              'トーナメント',
              _tournamentUpdates,
              (v) => setState(() => _tournamentUpdates = v),
            ),
            _buildSwitch(
              '実績解除',
              _achievements,
              (v) => setState(() => _achievements = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () async {
            await widget.onSave(NotificationPreference(
              allNotifications: _allNotifications,
              friendRequests: _friendRequests,
              gameInvitations: _gameInvitations,
              tournamentUpdates: _tournamentUpdates,
              achievements: _achievements,
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      // 「すべての通知」がオフのときは個別トグルの意味がないため無効化する
      // （実際のフィルタリングはNotificationPreference.allowsが行う）。
      onChanged: (label == 'すべての通知' || _allNotifications) ? onChanged : null,
    );
  }
}
