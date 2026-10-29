import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// `AppNotification`のCRUD + カテゴリ別設定フィルタリング。
/// komovia_shogi/komovia_goの`notification_service.dart`と同じ役割・
/// 同じFirestoreスキーマ（`notifications/{uid}/items/{id}`、設定は
/// `notifications/{uid}/notificationPreferences/settings`）。
/// `AppNotification`/`NotificationPreference`自体はkomovia_coreの
/// 共通モデルで、reversia独自のものは無い。
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> _itemsOf(String uid) =>
      _firestore.collection('notifications').doc(uid).collection('items');

  DocumentReference<Map<String, Object?>> _prefsOf(String uid) => _firestore
      .collection('notifications')
      .doc(uid)
      .collection('notificationPreferences')
      .doc('settings');

  Future<void> send({
    required String uid,
    required String title,
    required String body,
    required String type,
    Map<String, Object?>? data,
  }) async {
    final doc = _itemsOf(uid).doc();
    final notification = AppNotification(
      id: doc.id,
      uid: uid,
      title: title,
      body: body,
      data: data,
      type: type,
      isRead: false,
      createdAt: DateTime.now(),
    );
    await doc.set(notification.toJson());
  }

  Future<NotificationPreference> getPreferences(String uid) async {
    final doc = await _prefsOf(uid).get();
    if (!doc.exists) return const NotificationPreference();
    return NotificationPreference.fromJson(doc.data()!);
  }

  Future<void> savePreferences(String uid, NotificationPreference prefs) {
    return _prefsOf(uid).set(prefs.toJson());
  }

  /// [uid]の通知を、保存済みの設定でフィルタした上で返す。
  Future<List<AppNotification>> getNotifications(String uid) async {
    final prefs = await getPreferences(uid);
    final snap =
        await _itemsOf(uid).orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => AppNotification.fromJson(d.data()))
        .where((n) => prefs.allows(n.type))
        .toList();
  }

  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _itemsOf(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final prefs = await getPreferences(uid);
      return snap.docs
          .map((d) => AppNotification.fromJson(d.data()))
          .where((n) => prefs.allows(n.type))
          .toList();
    });
  }

  Future<void> markRead(String uid, String notificationId) {
    return _itemsOf(uid).doc(notificationId).update({
      'isRead': true,
      'readAt': DateTime.now().toIso8601String(),
    });
  }

  Future<int> unreadCount(String uid) async {
    final all = await getNotifications(uid);
    return all.where((n) => !n.isRead).length;
  }
}
