import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/notification_service.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final notificationsStreamProvider =
    StreamProvider.family<List<AppNotification>, String>(
  (ref, uid) => ref.watch(notificationServiceProvider).notificationsStream(uid),
);

final unreadNotificationCountProvider = Provider.family<int, String>((
  ref,
  uid,
) {
  final notifications = ref.watch(notificationsStreamProvider(uid)).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});

final markNotificationReadProvider = Provider(
  (ref) => (String uid, String id) =>
      ref.read(notificationServiceProvider).markRead(uid, id),
);

final notificationPreferenceProvider =
    FutureProvider.family<NotificationPreference, String>(
  (ref, uid) => ref.read(notificationServiceProvider).getPreferences(uid),
);

final saveNotificationPreferenceProvider = Provider(
  (ref) => (String uid, NotificationPreference prefs) =>
      ref.read(notificationServiceProvider).savePreferences(uid, prefs),
);
