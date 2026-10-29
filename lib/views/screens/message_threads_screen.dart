import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'chat_screen.dart';

/// メッセージスレッド一覧（受信箱） - komovia_chessの
/// `MessageThreadsScreen`と同じ役割（reversia向けに日本語化）。
/// フレンド一覧の「メッセージ」から既存/新規の会話に入る方式を主として
/// いるため、ここに新規会話を開始するボタンは置いていない。
class MessageThreadsScreen extends ConsumerWidget {
  const MessageThreadsScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(messageThreadsProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('メッセージ')),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return const Center(child: Text('まだ会話はありません'));
          }
          return ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final otherUid = thread.otherUidFor(uid);
              final otherName = thread.otherDisplayNameFor(uid);
              final unread = thread.unreadCountFor(uid);

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(otherName),
                subtitle: Text(
                  thread.lastMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread > 0
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: otherUid.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              currentUid: uid,
                              currentDisplayName: displayName,
                              friendUid: otherUid,
                              friendDisplayName: otherName,
                            ),
                          ),
                        ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'エラー: $err',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
