import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';
import 'package:komovia_reversia/services/premium_entitlement_service.dart';
import 'package:komovia_reversia/viewmodels/purchase_provider.dart';
import 'package:komovia_reversia/views/screens/paywall_screen.dart';

/// restorePurchases()が呼ばれたら[restored]を購入ストリームへ流す偽物。
class FakePurchaseService extends PurchaseService {
  FakePurchaseService(this.restored);

  final List<PurchaseDetails> restored;
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  int restoreCalls = 0;
  final completed = <String>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetails?> fetchProduct(String productId) async => null;

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    if (restored.isNotEmpty) {
      scheduleMicrotask(() => _controller.add(restored));
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.productID);
  }
}

PurchaseDetails restoredPurchase(String productId, DateTime date) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'test',
    ),
    transactionDate: '${date.millisecondsSinceEpoch}',
    status: PurchaseStatus.restored,
  );
}

void main() {
  group('restorePurchasesProvider', () {
    late FakeFirebaseFirestore firestore;
    late PremiumEntitlementService entitlements;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      entitlements = PremiumEntitlementService(firestore: firestore);
    });

    ProviderContainer containerWith(FakePurchaseService purchases) {
      final c = ProviderContainer(overrides: [
        purchaseServiceProvider.overrideWithValue(purchases),
        premiumEntitlementServiceProvider.overrideWithValue(entitlements),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('restored lifetime purchase is granted to the NEW uid', () async {
      final purchases = FakePurchaseService([
        restoredPurchase(PurchaseService.lifetimeProductId,
            DateTime.now().subtract(const Duration(days: 400))),
      ]);
      final c = containerWith(purchases);

      final ok = await c.read(restorePurchasesProvider)('new-uid');

      expect(ok, isTrue);
      expect(purchases.restoreCalls, 1);
      final e = await entitlements.getEntitlement('new-uid');
      expect(e!.plan, SubscriptionPlan.lifetime);
      expect(e.isCurrentlyActive(), isTrue);
      expect(purchases.completed, [PurchaseService.lifetimeProductId]);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('returns false when nothing is restored', () async {
      final c = containerWith(FakePurchaseService([]));
      expect(await c.read(restorePurchasesProvider)('u1'), isFalse);
      expect(await entitlements.getEntitlement('u1'), isNull);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('does not revive an already-expired monthly subscription', () async {
      final c = containerWith(FakePurchaseService([
        restoredPurchase(PurchaseService.monthlyProductId,
            DateTime.now().subtract(const Duration(days: 90))),
      ]));
      expect(await c.read(restorePurchasesProvider)('u1'), isFalse);
      expect(await entitlements.getEntitlement('u1'), isNull);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('restores a still-valid monthly with its original expiry', () async {
      final bought = DateTime.now().subtract(const Duration(days: 10));
      final c = containerWith(FakePurchaseService([
        restoredPurchase(PurchaseService.monthlyProductId, bought),
      ]));
      expect(await c.read(restorePurchasesProvider)('u1'), isTrue);
      final e = await entitlements.getEntitlement('u1');
      expect(e!.expiresAt!.isBefore(DateTime.now().add(const Duration(days: 25))),
          isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  testWidgets('paywall shows a tappable restore button', (tester) async {
    var calls = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        premiumEntitlementServiceProvider.overrideWithValue(
            PremiumEntitlementService(firestore: FakeFirebaseFirestore())),
        purchaseServiceProvider.overrideWithValue(FakePurchaseService([])),
        restorePurchasesProvider.overrideWithValue((uid) async {
          calls++;
          return false;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: const PaywallScreen(uid: 'u1'),
      ),
    ));
    await tester.pump();

    final button = find.byKey(const Key('restorePurchasesButton'));
    expect(button, findsOneWidget);
    expect(find.text('購入を復元'), findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(calls, 1);
    expect(find.text('復元できる購入が見つかりませんでした'), findsOneWidget);
  });
}
