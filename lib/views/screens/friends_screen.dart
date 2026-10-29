import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'chat_screen.dart';

/// フレンド画面 - komovia_shogiの`FriendsScreen`と同じ役割（reversia向け
/// に日本語化）。「フレンド」「招待待ち」の2タブ構成で、`FriendService`
/// （komovia_coreの`Friendship`共通モデルを使用）を薄く表示する。
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('フレンド'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'フレンドを追加',
              onPressed: () => _showAddFriendDialog(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'フレンド'),
              Tab(text: '招待待ち'),
              Tab(text: 'ブロック中'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsTab(context, ref),
            _buildPendingTab(ref),
            _buildBlockedTab(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsStreamProvider(uid)).value ?? [];
    if (friends.isEmpty) {
      return const Center(child: Text('フレンドはまだいません'));
    }
    return ListView(
      children: friends
          .map(
            (f) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(f.displayName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined),
                    tooltip: 'メッセージ',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          currentUid: uid,
                          currentDisplayName: displayName,
                          friendUid: f.friendUid,
                          friendDisplayName: f.displayName,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.block),
                    tooltip: 'ブロック',
                    onPressed: () =>
                        ref.read(blockFriendProvider)(uid, f.friendUid),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPendingTab(WidgetRef ref) {
    final pending = ref.watch(pendingFriendsStreamProvider(uid)).value ?? [];
    if (pending.isEmpty) {
      return const Center(child: Text('招待待ちの申請はありません'));
    }
    return ListView(
      children: pending.map((f) {
        final incoming = !f.wasRequestedBy(uid);
        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(f.displayName),
          subtitle: Text(incoming ? '申請が届いています' : '送信済み - 相手の返答待ち'),
          trailing: incoming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: '承認する',
                      onPressed: () =>
                          ref.read(acceptFriendRequestProvider)(uid, f.friendUid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: '拒否する',
                      onPressed: () =>
                          ref.read(rejectFriendRequestProvider)(uid, f.friendUid),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () =>
                      ref.read(rejectFriendRequestProvider)(uid, f.friendUid),
                  child: const Text('キャンセル'),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildBlockedTab(WidgetRef ref) {
    final blocked = ref.watch(blockedFriendsStreamProvider(uid)).value ?? [];
    if (blocked.isEmpty) {
      return const Center(child: Text('ブロック中のフレンドはいません'));
    }
    return ListView(
      children: blocked.map((f) {
        return ListTile(
          leading: const Icon(Icons.block, color: Colors.red),
          title: Text(f.displayName),
          trailing: TextButton(
            onPressed: () =>
                ref.read(unblockFriendProvider)(uid, f.friendUid),
            child: const Text('ブロック解除'),
          ),
        );
      }).toList(),
    );
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フレンドを追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '相手のUID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final toUid = controller.text.trim();
              if (toUid.isNotEmpty && toUid != uid) {
                ref.read(sendFriendRequestProvider)(uid, displayName, toUid);
              }
              Navigator.pop(ctx);
            },
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }
}
