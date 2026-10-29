import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_search_result.dart';
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
    var results = <UserSearchResult>[];
    var searching = false;
    var sentToUid = <String>{};

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> runSearch(String query) async {
            setState(() => searching = true);
            final found = await ref.read(searchUsersByDisplayNameProvider)(query, uid);
            setState(() {
              results = found;
              searching = false;
            });
          }

          return AlertDialog(
            title: const Text('フレンドを追加'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '表示名で検索',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: runSearch,
                  ),
                  const SizedBox(height: 8),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('検索ボックスに表示名を入れて検索してください'),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        shrinkWrap: true,
                        children: results.map((r) {
                          final alreadySent = sentToUid.contains(r.uid);
                          return ListTile(
                            title: Text(r.displayName),
                            trailing: alreadySent
                                ? const Icon(Icons.check, color: Colors.green)
                                : TextButton(
                                    onPressed: () async {
                                      await ref.read(sendFriendRequestProvider)(
                                        uid,
                                        displayName,
                                        r.uid,
                                      );
                                      setState(() => sentToUid = {...sentToUid, r.uid});
                                    },
                                    child: const Text('申請'),
                                  ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => runSearch(controller.text),
                child: const Text('検索'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }
}
