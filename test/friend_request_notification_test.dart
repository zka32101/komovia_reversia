import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/friend_service.dart';
import 'package:komovia_reversia/services/notification_service.dart';
import 'package:komovia_reversia/viewmodels/friend_provider.dart';
import 'package:komovia_reversia/viewmodels/notification_provider.dart';

void main() {
  test('sendFriendRequestProvider sends a friend_request notification to the recipient', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set({'displayName': 'Alice'});
    await firestore.collection('users').doc('u2').set({'displayName': 'Bob'});

    final container = ProviderContainer(overrides: [
      friendServiceProvider.overrideWithValue(FriendService(firestore: firestore)),
      notificationServiceProvider.overrideWithValue(NotificationService(firestore: firestore)),
    ]);
    addTearDown(container.dispose);

    await container.read(sendFriendRequestProvider)('u1', 'Alice', 'u2');

    final notifications = await container
        .read(notificationServiceProvider)
        .notificationsStream('u2')
        .first;
    expect(notifications, hasLength(1));
    expect(notifications.first.type, 'friend_request');
    expect(notifications.first.title, contains('Alice'));
  });
}
