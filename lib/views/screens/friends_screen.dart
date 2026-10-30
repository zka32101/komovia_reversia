import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.homeFriendsTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: l10n.friendsAddTooltip,
              onPressed: () => _showAddFriendDialog(context, ref),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.homeFriendsTitle),
              Tab(text: l10n.friendsPendingTab),
              Tab(text: l10n.friendsBlockedTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsTab(context, ref, l10n),
            _buildPendingTab(ref, l10n),
            _buildBlockedTab(ref, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final friends = ref.watch(friendsStreamProvider(uid)).value ?? [];
    if (friends.isEmpty) {
      return Center(child: Text(l10n.friendsEmptyMessage));
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
                    tooltip: l10n.messagesTitle,
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
                    tooltip: l10n.friendsBlockTooltip,
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

  Widget _buildPendingTab(WidgetRef ref, AppLocalizations l10n) {
    final pending = ref.watch(pendingFriendsStreamProvider(uid)).value ?? [];
    if (pending.isEmpty) {
      return Center(child: Text(l10n.friendsPendingEmptyMessage));
    }
    return ListView(
      children: pending.map((f) {
        final incoming = !f.wasRequestedBy(uid);
        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(f.displayName),
          subtitle: Text(
            incoming ? l10n.friendsIncomingRequestLabel : l10n.friendsSentRequestLabel,
          ),
          trailing: incoming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: l10n.friendsAcceptTooltip,
                      onPressed: () =>
                          ref.read(acceptFriendRequestProvider)(uid, f.friendUid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: l10n.friendsRejectTooltip,
                      onPressed: () =>
                          ref.read(rejectFriendRequestProvider)(uid, f.friendUid),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () =>
                      ref.read(rejectFriendRequestProvider)(uid, f.friendUid),
                  child: Text(l10n.cancelButton),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildBlockedTab(WidgetRef ref, AppLocalizations l10n) {
    final blocked = ref.watch(blockedFriendsStreamProvider(uid)).value ?? [];
    if (blocked.isEmpty) {
      return Center(child: Text(l10n.friendsBlockedEmptyMessage));
    }
    return ListView(
      children: blocked.map((f) {
        return ListTile(
          leading: const Icon(Icons.block, color: Colors.red),
          title: Text(f.displayName),
          trailing: TextButton(
            onPressed: () =>
                ref.read(unblockFriendProvider)(uid, f.friendUid),
            child: Text(l10n.friendsUnblockButton),
          ),
        );
      }).toList(),
    );
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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
            title: Text(l10n.friendsAddTooltip),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: l10n.friendsSearchByDisplayNameLabel,
                      prefixIcon: const Icon(Icons.search),
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
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.friendsSearchHintMessage),
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
                                    child: Text(l10n.friendsRequestButton),
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
                child: Text(l10n.friendsSearchButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.closeButton),
              ),
            ],
          );
        },
      ),
    );
  }
}
