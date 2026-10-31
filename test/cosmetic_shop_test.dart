import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';
import 'package:komovia_reversia/services/board_theme_preferences.dart';
import 'package:komovia_reversia/src/reversia_board_theme.dart';
import 'package:komovia_reversia/src/reversia_cosmetics.dart';
import 'package:komovia_reversia/viewmodels/purchase_provider.dart';
import 'package:komovia_reversia/views/screens/cosmetic_shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReversiaCosmetics catalog', () {
    test('has free and supporter skins in both categories, unique ids', () {
      for (final items in [
        ReversiaCosmetics.boardSkins.map((s) => s.item),
        ReversiaCosmetics.discSkins.map((s) => s.item),
      ]) {
        final list = items.toList();
        expect(list.where((i) => i.isFreeForAll).length, greaterThanOrEqualTo(2));
        expect(list.where((i) => i.includedWithSubscription).length, greaterThanOrEqualTo(2));
        expect(list.map((i) => i.id).toSet().length, list.length);
      }
      expect(ReversiaCosmetics.boardSkins.every((s) => s.item.category == boardSkinCategory), isTrue);
      expect(ReversiaCosmetics.discSkins.every((s) => s.item.category == discSkinCategory), isTrue);
    });

    test('ownership: free always, supporter skins only with subscription', () {
      final marble = ReversiaCosmetics.boardSkinById('marble').item;
      expect(ReversiaCosmetics.isOwned(marble, hasActiveSubscription: false), isFalse);
      expect(ReversiaCosmetics.isOwned(marble, hasActiveSubscription: true), isTrue);
      final sumi = ReversiaCosmetics.boardSkinById('sumi').item;
      expect(ReversiaCosmetics.isOwned(sumi, hasActiveSubscription: false), isTrue);
    });

    test('matching legacy ids resolve to the existing theme constant', () {
      expect(
        ReversiaCosmetics.resolveTheme(boardSkinId: 'emerald', discSkinId: 'emerald', hasActiveSubscription: false),
        ReversiaBoardTheme.emerald,
      );
      expect(
        ReversiaCosmetics.resolveTheme(boardSkinId: null, discSkinId: null, hasActiveSubscription: false),
        ReversiaBoardTheme.classic,
      );
    });

    test('mixed skins compose; unowned supporter skins fall back to default', () {
      final t = ReversiaCosmetics.resolveTheme(
          boardSkinId: 'neon', discSkinId: 'glass', hasActiveSubscription: true);
      expect(t.lightSquare, ReversiaCosmetics.boardSkinById('neon').lightSquare);
      expect(t.frontPieceColor, ReversiaCosmetics.discSkinById('glass').frontColor);
      expect(t.discGloss, isTrue);
      expect(t.gridLineColor, isNotNull);

      expect(
        ReversiaCosmetics.resolveTheme(boardSkinId: 'neon', discSkinId: 'glass', hasActiveSubscription: false),
        ReversiaBoardTheme.classic,
      );
    });
  });

  group('BoardThemePreferences skins', () {
    test('legacy theme id seeds both skin ids', () async {
      SharedPreferences.setMockInitialValues({'reversia_board_theme_id': 'sumi'});
      final prefs = BoardThemePreferences();
      expect(await prefs.getBoardSkinId(), 'sumi');
      expect(await prefs.getDiscSkinId(), 'sumi');
      expect(await prefs.getTheme(), ReversiaBoardTheme.sumi);
    });

    test('skin selections persist and gate on subscription', () async {
      final prefs = BoardThemePreferences();
      await prefs.setBoardSkinId('marble');
      await prefs.setDiscSkinId('sumi');
      expect(await prefs.getBoardSkinId(), 'marble');
      final withSub = await prefs.getTheme(hasActiveSubscription: true);
      expect(withSub.lightSquare, ReversiaCosmetics.boardSkinById('marble').lightSquare);
      final withoutSub = await prefs.getTheme();
      expect(withoutSub.lightSquare, ReversiaBoardTheme.classic.lightSquare);
      expect(withoutSub.frontPieceColor, ReversiaBoardTheme.sumi.frontPieceColor);
    });
  });

  group('CosmeticShopScreen', () {
    Future<void> pump(WidgetTester tester, {required bool premium}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [isPremiumProvider.overrideWithValue(premium)],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CosmeticShopScreen(uid: 'u1'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('selecting a free skin persists it', (tester) async {
      await pump(tester, premium: false);
      expect(find.byKey(const ValueKey('cosmetic-boardSkin-classic')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cosmetic-boardSkin-emerald')));
      await tester.pumpAndSettle();
      expect(await BoardThemePreferences().getBoardSkinId(), 'emerald');
    });

    testWidgets('locked supporter skin is not selected and shows upsell', (tester) async {
      await pump(tester, premium: false);
      await tester.tap(find.byKey(const ValueKey('cosmetic-discSkin-glass')));
      await tester.pump();
      expect(find.text('このスキンはプレミアムサポーター特典です'), findsOneWidget);
      expect(find.text('サポーターになる'), findsOneWidget);
      expect(await BoardThemePreferences().getDiscSkinId(), 'classic');
    });

    testWidgets('supporter can select supporter skin', (tester) async {
      await pump(tester, premium: true);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cosmetic-discSkin-glass')));
      await tester.pumpAndSettle();
      expect(await BoardThemePreferences().getDiscSkinId(), 'glass');
    });
  });
}
