import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/premium_entitlement_service.dart';
import 'package:komovia_reversia/viewmodels/purchase_provider.dart';
import 'package:komovia_reversia/views/screens/legal_document_screen.dart';
import 'package:komovia_reversia/views/screens/paywall_screen.dart';
import 'package:komovia_reversia/views/screens/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, {String? uid}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumEntitlementServiceProvider.overrideWithValue(
            PremiumEntitlementService(firestore: FakeFirebaseFirestore()),
          ),
        ],
        child: MaterialApp(home: SettingsScreen(uid: uid)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows links to privacy policy and terms of service', (tester) async {
    await pumpSettings(tester);

    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
  });

  testWidgets('hides the premium entry when signed out', (tester) async {
    await pumpSettings(tester);

    expect(find.text('プレミアムサポーター'), findsNothing);
  });

  testWidgets('shows and opens the premium entry when signed in', (tester) async {
    await pumpSettings(tester, uid: 'u1');
    expect(find.text('プレミアムサポーター'), findsOneWidget);

    await tester.tap(find.text('プレミアムサポーター'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('tapping プライバシーポリシー opens the privacy policy document', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('プライバシーポリシー'));
    await tester.pumpAndSettle();

    final screen = tester.widget<LegalDocumentScreen>(
      find.byType(LegalDocumentScreen),
    );
    expect(screen.kind, LegalDocumentKind.privacyPolicy);
    expect(find.textContaining('Firebase Authentication'), findsOneWidget);
  });

  testWidgets('tapping 利用規約 opens the terms of service document', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('利用規約'));
    await tester.pumpAndSettle();

    final screen = tester.widget<LegalDocumentScreen>(
      find.byType(LegalDocumentScreen),
    );
    expect(screen.kind, LegalDocumentKind.termsOfService);
    expect(find.textContaining('本アプリの利用にあたり'), findsOneWidget);
  });
}
