import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';
import 'package:komovia_reversia/services/account_data_deletion_service.dart';
import 'package:komovia_reversia/services/auth_service.dart';
import 'package:komovia_reversia/services/premium_entitlement_service.dart';
import 'package:komovia_reversia/src/reversia_weekly_goal.dart';
import 'package:komovia_reversia/viewmodels/purchase_provider.dart';
import 'package:komovia_reversia/views/screens/account_screen.dart';
import 'package:komovia_reversia/views/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uid = 'anon-uid-123';

/// firebase_auth_mocks 0.13's `MockUser.linkWithCredential` asserts that the
/// returned credential's anonymity matches the user's, which makes linking an
/// anonymous user impossible to exercise. Real Firebase returns the same
/// user (same uid) as no-longer-anonymous; model just that.
class _LinkableAnonUser extends MockUser {
  _LinkableAnonUser() : super(isAnonymous: true, uid: _uid);

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async =>
      _Credential(MockUser(uid: uid, email: 'a@b.com'));
}

class _Credential implements UserCredential {
  _Credential(this.user);

  @override
  final User? user;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  AuthCredential? get credential => null;
}

Future<FakeFirebaseFirestore> _seededFirestore() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc(_uid).set({'displayName': 'me'});
  await db
      .collection('users')
      .doc(_uid)
      .collection('friends')
      .doc('f1')
      .set({'status': 'accepted'});
  await db
      .collection('users')
      .doc('f1')
      .collection('friends')
      .doc(_uid)
      .set({'status': 'accepted'});
  await db
      .collection('users')
      .doc('f1')
      .collection('friends')
      .doc('other')
      .set({'status': 'accepted'});
  await db
      .collection('premium_entitlements')
      .doc(_uid)
      .set({'isPremium': true});
  await db.collection('reversia_game_stats').doc(_uid).set({'wins': 3});
  await db.collection('reversia_difficulty_stats').doc(_uid).set({'x': 1});
  await db
      .collection('achievements')
      .doc(_uid)
      .collection('unlocked')
      .doc('a1')
      .set({'at': 1});
  await db
      .collection('notifications')
      .doc(_uid)
      .collection('items')
      .doc('n1')
      .set({'t': 'x'});
  await db
      .collection('reversia_puzzle_logs')
      .doc(_uid)
      .collection('days')
      .doc('2026-10-01')
      .set({'ok': true});
  await db
      .collection('leaderboards')
      .doc('all_time')
      .collection('rating')
      .doc(_uid)
      .set({'rating': 1300});
  await db
      .collection('reversia_weekly_progress')
      .doc('${_uid}_${reversiaWeekId(DateTime(2026, 10, 31, 12))}')
      .set({'gamesPlayed': 2});
  await db
      .collection('reversia_weekly_progress')
      .doc('${_uid}_${reversiaWeekId(DateTime(2026, 8, 1, 12))}')
      .set({'gamesPlayed': 1});
  await db
      .collection('reversia_weekly_progress')
      .doc('someone_${reversiaWeekId(DateTime(2026, 10, 31, 12))}')
      .set({'gamesPlayed': 9});
  await db
      .collection('reversia_pvp_games')
      .doc('g1')
      .set({'firstUid': _uid, 'secondUid': 'f1'});
  return db;
}

AuthService _service(MockFirebaseAuth auth, FakeFirebaseFirestore db) =>
    AuthService(
      auth: auth,
      dataDeletion: () => AccountDataDeletionService(firestore: db),
    );

void main() {
  group('AuthService.linkWithEmail', () {
    test('links the anonymous user in place, keeping its uid and data',
        () async {
      final db = await _seededFirestore();
      final auth =
          MockFirebaseAuth(signedIn: true, mockUser: _LinkableAnonUser());
      final service = _service(auth, db);

      final linked =
          await service.linkWithEmail(email: ' a@b.com ', password: 'secret1');

      // A LINK, not a new sign-in: same uid, so the premium entitlement and
      // records keyed by it remain reachable.
      expect(linked.uid, _uid);
      expect(auth.currentUser!.uid, _uid);
      expect(
          (await db.collection('premium_entitlements').doc(_uid).get()).exists,
          isTrue);
    });

    test('refuses when the current user is not anonymous', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(isAnonymous: false, uid: _uid, email: 'a@b.com'),
      );
      final service = _service(auth, FakeFirebaseFirestore());

      expect(
        () => service.linkWithEmail(email: 'x@y.com', password: 'secret1'),
        throwsA(isA<AuthServiceException>()),
      );
    });

    test('refuses when signed out', () async {
      final service = _service(MockFirebaseAuth(), FakeFirebaseFirestore());
      expect(
        () => service.linkWithEmail(email: 'x@y.com', password: 'secret1'),
        throwsA(isA<AuthServiceException>()),
      );
    });
  });

  group('AuthService.deleteAccount', () {
    test('deletes the user-owned data and leaves other users / shared data',
        () async {
      final db = await _seededFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(isAnonymous: true, uid: _uid),
      );

      final failed = await AccountDataDeletionService(firestore: db)
          .deleteAllUserData(_uid, now: DateTime(2026, 10, 31));
      await _service(auth, db).deleteAccount();

      expect(failed, isEmpty);
      Future<bool> exists(String path) async =>
          (await db.doc(path).get()).exists;
      for (final path in [
        'users/$_uid',
        'users/$_uid/friends/f1',
        'users/f1/friends/$_uid',
        'premium_entitlements/$_uid',
        'reversia_game_stats/$_uid',
        'reversia_difficulty_stats/$_uid',
        'achievements/$_uid/unlocked/a1',
        'notifications/$_uid/items/n1',
        'reversia_puzzle_logs/$_uid/days/2026-10-01',
        'leaderboards/all_time/rating/$_uid',
        'reversia_weekly_progress/${_uid}_${reversiaWeekId(DateTime(2026, 10, 31, 12))}',
        'reversia_weekly_progress/${_uid}_${reversiaWeekId(DateTime(2026, 8, 1, 12))}',
      ]) {
        expect(await exists(path), isFalse, reason: path);
      }
      // Other players' own data and shared game records are untouched.
      expect(await exists('users/f1/friends/other'), isTrue);
      expect(
        await exists(
            'reversia_weekly_progress/someone_${reversiaWeekId(DateTime(2026, 10, 31, 12))}'),
        isTrue,
      );
      expect(await exists('reversia_pvp_games/g1'), isTrue);
    });

    test('throws when signed out', () async {
      expect(
        () => _service(MockFirebaseAuth(), FakeFirebaseFirestore())
            .deleteAccount(),
        throwsA(isA<AuthServiceException>()),
      );
    });
  });

  group('AccountScreen', () {
    Future<void> pump(WidgetTester tester, AuthService service) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountScreen(authService: service),
      ));
      await tester.pump();
    }

    testWidgets('a guest sees the link form and links the account',
        (tester) async {
      final auth =
          MockFirebaseAuth(signedIn: true, mockUser: _LinkableAnonUser());
      await pump(tester, _service(auth, FakeFirebaseFirestore()));

      expect(find.textContaining('ゲストとしてプレイ中'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('link_email')), 'a@b.com');
      await tester.enterText(find.byKey(const Key('link_password')), 'secret1');
      await tester.tap(find.text('このアカウントを連携する'));
      await tester.pump();
      await tester.pump();

      expect(find.text('アカウントを連携しました'), findsOneWidget);
      expect(auth.currentUser!.uid, _uid);
    });

    testWidgets('a linked user sees the linked email and no link form',
        (tester) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(isAnonymous: false, uid: _uid, email: 'a@b.com'),
      );
      await pump(tester, _service(auth, FakeFirebaseFirestore()));

      expect(find.textContaining('a@b.com と連携済み'), findsOneWidget);
      expect(find.text('このアカウントを連携する'), findsNothing);
      expect(find.text('ログイン'), findsNothing);
    });

    testWidgets('delete asks for confirmation and cancel keeps the account',
        (tester) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(isAnonymous: true, uid: _uid),
      );
      await pump(tester, _service(auth, await _seededFirestore()));

      await tester.scrollUntilVisible(find.text('アカウントを削除'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      expect(find.text('アカウントを削除しますか？'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('アカウントを削除しました'), findsNothing);
      expect(auth.currentUser, isNotNull);
    });

    testWidgets('confirming delete removes the account', (tester) async {
      final db = await _seededFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(isAnonymous: true, uid: _uid),
      );
      await pump(tester, _service(auth, db));

      await tester.scrollUntilVisible(find.text('アカウントを削除'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除する'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('アカウントを削除しました'), findsOneWidget);
      expect(
          (await db.doc('premium_entitlements/$_uid').get()).exists, isFalse);
    });
  });

  testWidgets('settings has an entry that opens the account screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(isAnonymous: true, uid: _uid),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        premiumEntitlementServiceProvider.overrideWithValue(
          PremiumEntitlementService(firestore: FakeFirebaseFirestore()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
            authService: _service(auth, FakeFirebaseFirestore())),
      ),
    ));
    await tester.pumpAndSettle();

    final entry = find.text('機種変更に備えてアカウントを連携');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
  });
}
