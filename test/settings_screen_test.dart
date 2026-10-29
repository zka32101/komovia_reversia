import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/views/screens/legal_document_screen.dart';
import 'package:komovia_reversia/views/screens/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  }

  testWidgets('shows links to privacy policy and terms of service', (tester) async {
    await pumpSettings(tester);

    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
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
