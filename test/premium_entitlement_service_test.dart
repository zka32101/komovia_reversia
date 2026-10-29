import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/services/premium_entitlement_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PremiumEntitlementService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = PremiumEntitlementService(firestore: firestore);
  });

  test('getEntitlement returns null when nothing was ever granted', () async {
    expect(await service.getEntitlement('u1'), isNull);
  });

  test('a monthly entitlement is active until it expires', () async {
    await service.grantEntitlement(uid: 'u1', plan: SubscriptionPlan.monthly);

    final entitlement = await service.getEntitlement('u1');
    expect(entitlement!.plan, SubscriptionPlan.monthly);
    expect(entitlement.isCurrentlyActive(now: DateTime.now()), isTrue);
    expect(
      entitlement.isCurrentlyActive(
        now: DateTime.now().add(const Duration(days: 31)),
      ),
      isFalse,
    );
  });

  test('a lifetime entitlement never expires', () async {
    await service.grantEntitlement(uid: 'u1', plan: SubscriptionPlan.lifetime);

    final entitlement = await service.getEntitlement('u1');
    expect(entitlement!.expiresAt, isNull);
    expect(
      entitlement.isCurrentlyActive(
        now: DateTime.now().add(const Duration(days: 365 * 10)),
      ),
      isTrue,
    );
  });

  test('skipIfAlreadyActive does not push out an already-active expiry', () async {
    final now = DateTime.now();
    await service.grantEntitlement(uid: 'u1', plan: SubscriptionPlan.monthly);
    final firstExpiry = (await service.getEntitlement('u1'))!.expiresAt!;

    await service.grantEntitlement(
      uid: 'u1',
      plan: SubscriptionPlan.monthly,
      skipIfAlreadyActive: true,
    );
    final secondExpiry = (await service.getEntitlement('u1'))!.expiresAt!;

    expect(secondExpiry, firstExpiry);
    expect(firstExpiry.isAfter(now), isTrue);
  });

  test('skipIfAlreadyActive still grants when the previous entitlement already expired', () async {
    await firestore.collection('premium_entitlements').doc('u1').set({
      'plan': SubscriptionPlan.monthly.name,
      'startedAt': DateTime.now()
          .subtract(const Duration(days: 60))
          .toIso8601String(),
      'expiresAt': DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String(),
    });

    await service.grantEntitlement(
      uid: 'u1',
      plan: SubscriptionPlan.annual,
      skipIfAlreadyActive: true,
    );

    final entitlement = await service.getEntitlement('u1');
    expect(entitlement!.plan, SubscriptionPlan.annual);
    expect(entitlement.isCurrentlyActive(), isTrue);
  });

  test('watchEntitlement reflects the current document', () async {
    await service.grantEntitlement(uid: 'u1', plan: SubscriptionPlan.annual);

    final entitlement = await service.watchEntitlement('u1').first;
    expect(entitlement!.plan, SubscriptionPlan.annual);
  });
}
