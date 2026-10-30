import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/services/premium_entitlement_service.dart';
import 'package:komovia_reversia/viewmodels/purchase_provider.dart';
import 'package:komovia_reversia/views/screens/paywall_screen.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';

void main() {
  Future<PremiumEntitlementService> pumpScreen(
    WidgetTester tester, {
    String uid = 'u1',
  }) async {
    final firestore = FakeFirebaseFirestore();
    final service = PremiumEntitlementService(firestore: firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [premiumEntitlementServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaywallScreen(uid: uid)),
      ),
    );
    await tester.pump();
    await tester.pump();
    return service;
  }

  testWidgets('shows all three plan options when not a supporter', (tester) async {
    await pumpScreen(tester);

    expect(find.text('月額プラン'), findsOneWidget);
    expect(find.text('年額プラン'), findsOneWidget);
    expect(find.text('買い切りプラン'), findsOneWidget);
    expect(find.text('購入する'), findsNWidgets(3));
  });

  testWidgets('shows a supporter banner instead of plan cards once active', (tester) async {
    final service = await pumpScreen(tester);
    await service.grantEntitlement(uid: 'u1', plan: SubscriptionPlan.lifetime);

    await tester.pump();
    await tester.pump();

    expect(find.textContaining('すでにサポーターです'), findsOneWidget);
    expect(find.text('購入する'), findsNothing);
  });
}
