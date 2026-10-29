import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('send persists a notification readable by getNotifications',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);

      await service.send(
        uid: 'u1',
        title: 'タイトル',
        body: '本文',
        type: 'pvp_challenge',
        data: {'gameId': 'g1'},
      );

      final notifications = await service.getNotifications('u1');
      expect(notifications, hasLength(1));
      expect(notifications.single.title, 'タイトル');
      expect(notifications.single.data?['gameId'], 'g1');
      expect(notifications.single.isRead, isFalse);
    });

    test('getNotifications orders by createdAt descending', () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);

      await service.send(uid: 'u1', title: '古い', body: '', type: 'other');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.send(uid: 'u1', title: '新しい', body: '', type: 'other');

      final notifications = await service.getNotifications('u1');
      expect(notifications.first.title, '新しい');
      expect(notifications.last.title, '古い');
    });

    test('markRead sets isRead/readAt', () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);
      await service.send(uid: 'u1', title: 'タイトル', body: '', type: 'other');
      final id = (await service.getNotifications('u1')).single.id;

      await service.markRead('u1', id);

      final notification = (await service.getNotifications('u1')).single;
      expect(notification.isRead, isTrue);
      expect(notification.readAt, isNotNull);
    });

    test('unreadCount counts only unread notifications', () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);
      await service.send(uid: 'u1', title: 'A', body: '', type: 'other');
      await service.send(uid: 'u1', title: 'B', body: '', type: 'other');
      final ids = (await service.getNotifications('u1')).map((n) => n.id).toList();
      await service.markRead('u1', ids.first);

      expect(await service.unreadCount('u1'), 1);
    });

    test(
        'a notification of a disabled category is filtered out by getNotifications',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);
      await service.savePreferences(
        'u1',
        const NotificationPreference(gameInvitations: false),
      );
      await service.send(
        uid: 'u1',
        title: '対局の招待',
        body: '',
        type: 'pvp_challenge',
      );

      expect(await service.getNotifications('u1'), isEmpty);
    });

    test('allNotifications: false overrides every individual category',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);
      await service.savePreferences(
        'u1',
        const NotificationPreference(allNotifications: false),
      );
      await service.send(uid: 'u1', title: 'タイトル', body: '', type: 'other');

      expect(await service.getNotifications('u1'), isEmpty);
    });

    test('an unrecognized notification type defaults to shown', () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);
      await service.savePreferences(
        'u1',
        const NotificationPreference(gameInvitations: false),
      );
      await service.send(
        uid: 'u1',
        title: 'タイトル',
        body: '',
        type: 'some_future_type',
      );

      expect(await service.getNotifications('u1'), hasLength(1));
    });

    test('notificationsStream reflects the same filtering as getNotifications',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = NotificationService(firestore: firestore);
      await service.savePreferences(
        'u1',
        const NotificationPreference(gameInvitations: false),
      );
      await service.send(uid: 'u1', title: 'A', body: '', type: 'other');
      await service.send(uid: 'u1', title: 'B', body: '', type: 'pvp_challenge');

      final emitted = await service.notificationsStream('u1').first;
      expect(emitted, hasLength(1));
      expect(emitted.single.title, 'A');
    });
  });
}
