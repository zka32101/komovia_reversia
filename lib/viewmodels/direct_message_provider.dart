import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/direct_message_service.dart';
import 'auth_provider.dart';

final directMessageServiceProvider =
    Provider<DirectMessageService>((ref) => DirectMessageService());

/// [uid]が参加している全メッセージスレッド（新しい順）。
final messageThreadsProvider =
    StreamProvider.family<List<MessageThread>, String>((ref, uid) {
  return ref.watch(directMessageServiceProvider).watchThreadsForUser(uid);
});

/// 1つのスレッド内のメッセージ一覧（古い順）。
final threadMessagesProvider =
    StreamProvider.family<List<DirectMessage>, String>((ref, threadId) {
  return ref.watch(directMessageServiceProvider).watchMessages(threadId);
});

/// 現在のユーザーの全スレッドをまたいだ未読メッセージ数の合計。
final unreadMessageCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return 0;
  final threads = ref.watch(messageThreadsProvider(uid)).value;
  if (threads == null) return 0;
  return threads.fold<int>(0, (sum, thread) => sum + thread.unreadCountFor(uid));
});

final sendDirectMessageProvider = Provider((ref) {
  final service = ref.watch(directMessageServiceProvider);
  return ({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String content,
  }) {
    return service.sendMessage(
      fromUid: fromUid,
      fromDisplayName: fromDisplayName,
      toUid: toUid,
      toDisplayName: toDisplayName,
      content: content,
    );
  };
});

final markThreadReadProvider = Provider((ref) {
  final service = ref.watch(directMessageServiceProvider);
  return ({required String threadId, required String uid}) {
    return service.markThreadRead(threadId: threadId, uid: uid);
  };
});
