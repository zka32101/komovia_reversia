import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/avatar_preferences.dart';
import 'package:komovia_reversia/services/daily_reminder_preferences.dart';
import 'package:komovia_reversia/services/premium_entitlement_service.dart';
import 'package:komovia_reversia/services/sound_feedback_preferences.dart';
import 'package:komovia_reversia/src/reversia_avatar.dart';
import 'package:komovia_reversia/utils/reversia_move_feedback.dart';
import 'package:komovia_reversia/viewmodels/purchase_provider.dart';
import 'package:komovia_reversia/views/screens/how_to_play_screen.dart';
import 'package:komovia_reversia/views/screens/legal_document_screen.dart';
import 'package:komovia_reversia/views/screens/paywall_screen.dart';
import 'package:komovia_reversia/views/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService implements LocalNotificationServiceLike {
  bool permissionGranted = true;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int? lastHour;
  int? lastMinute;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    scheduleCalls++;
    lastHour = hour;
    lastMinute = minute;
  }

  @override
  Future<void> cancelDailyReminder() async {
    cancelCalls++;
  }
}

class _FakePreferences implements DailyReminderPreferencesLike {
  bool enabled;
  int hour;
  int minute;

  _FakePreferences({
    this.enabled = false,
    this.hour = DailyReminderPreferences.defaultHour,
    this.minute = DailyReminderPreferences.defaultMinute,
  });

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<int> getHour() async => hour;

  @override
  Future<int> getMinute() async => minute;

  @override
  Future<void> setTime(int newHour, int newMinute) async {
    hour = newHour;
    minute = newMinute;
  }
}

class _FakeSoundFeedbackPreferences implements SoundFeedbackPreferencesLike {
  bool enabled;

  _FakeSoundFeedbackPreferences({this.enabled = true});

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class _FakeAvatarPreferences implements AvatarPreferencesLike {
  ReversiaAvatar avatar;

  _FakeAvatarPreferences({this.avatar = ReversiaAvatar.defaultAvatar});

  @override
  Future<ReversiaAvatar> getAvatar() async => avatar;

  @override
  Future<void> setAvatar(ReversiaAvatar newAvatar) async => avatar = newAvatar;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    reversiaFeedbackEnabled = true;
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    String? uid,
    LocalNotificationServiceLike? notificationService,
    DailyReminderPreferencesLike? preferences,
    SoundFeedbackPreferencesLike? soundFeedbackPreferences,
    AvatarPreferencesLike? avatarPreferences,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumEntitlementServiceProvider.overrideWithValue(
            PremiumEntitlementService(firestore: FakeFirebaseFirestore()),
          ),
        ],
        child: MaterialApp(
          home: SettingsScreen(
            uid: uid,
            notificationService: notificationService ?? _FakeNotificationService(),
            preferences: preferences ?? _FakePreferences(),
            soundFeedbackPreferences:
                soundFeedbackPreferences ?? _FakeSoundFeedbackPreferences(),
            avatarPreferences: avatarPreferences ?? _FakeAvatarPreferences(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows links to privacy policy and terms of service', (tester) async {
    await pumpSettings(tester);

    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
  });

  testWidgets('tapping 遊び方 opens the how-to-play screen', (tester) async {
    await pumpSettings(tester);

    expect(find.text('遊び方'), findsOneWidget);
    await tester.tap(find.text('遊び方'));
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text('駒の表と裏'), findsOneWidget);
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

  testWidgets('shows the daily reminder off by default', (tester) async {
    await pumpSettings(tester);

    expect(find.text('デイリーリマインダー'), findsOneWidget);
    expect(find.text('オフ'), findsOneWidget);
    expect(find.text('通知時刻'), findsNothing);
  });

  testWidgets('loads a previously-enabled reminder and shows its time', (tester) async {
    final prefs = _FakePreferences(enabled: true, hour: 8, minute: 30);
    await pumpSettings(tester, preferences: prefs);

    expect(find.text('毎日 8:30 に通知'), findsOneWidget);
    expect(find.text('通知時刻'), findsOneWidget);
  });

  testWidgets('enabling the reminder requests permission and schedules it', (tester) async {
    final notificationService = _FakeNotificationService();
    final prefs = _FakePreferences();
    await pumpSettings(
      tester,
      notificationService: notificationService,
      preferences: prefs,
    );

    await tester.tap(find.widgetWithIcon(SwitchListTile, Icons.notifications_active_outlined));
    await tester.pumpAndSettle();

    expect(notificationService.scheduleCalls, 1);
    expect(notificationService.lastHour, DailyReminderPreferences.defaultHour);
    expect(notificationService.lastMinute, DailyReminderPreferences.defaultMinute);
    expect(prefs.enabled, true);
    expect(find.text('毎日 19:00 に通知'), findsOneWidget);
  });

  testWidgets('shows a snackbar and stays off when permission is denied', (tester) async {
    final notificationService = _FakeNotificationService()..permissionGranted = false;
    final prefs = _FakePreferences();
    await pumpSettings(
      tester,
      notificationService: notificationService,
      preferences: prefs,
    );

    await tester.tap(find.widgetWithIcon(SwitchListTile, Icons.notifications_active_outlined));
    await tester.pumpAndSettle();

    expect(find.text('通知の許可が必要です'), findsOneWidget);
    expect(notificationService.scheduleCalls, 0);
    expect(prefs.enabled, false);
    expect(
      find.descendant(
        of: find.widgetWithIcon(SwitchListTile, Icons.notifications_active_outlined),
        matching: find.text('オフ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('disabling the reminder cancels it', (tester) async {
    final notificationService = _FakeNotificationService();
    final prefs = _FakePreferences(enabled: true, hour: 9, minute: 0);
    await pumpSettings(
      tester,
      notificationService: notificationService,
      preferences: prefs,
    );
    expect(find.text('通知時刻'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(SwitchListTile, Icons.notifications_active_outlined));
    await tester.pumpAndSettle();

    expect(notificationService.cancelCalls, 1);
    expect(prefs.enabled, false);
    expect(
      find.descendant(
        of: find.widgetWithIcon(SwitchListTile, Icons.notifications_active_outlined),
        matching: find.text('オフ'),
      ),
      findsOneWidget,
    );
    expect(find.text('通知時刻'), findsNothing);
  });

  testWidgets('picking a new time reschedules the reminder when enabled', (tester) async {
    final notificationService = _FakeNotificationService();
    final prefs = _FakePreferences(enabled: true, hour: 9, minute: 0);
    await pumpSettings(
      tester,
      notificationService: notificationService,
      preferences: prefs,
    );

    await tester.tap(find.text('通知時刻'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(notificationService.scheduleCalls, 1);
    expect(prefs.hour, notificationService.lastHour);
    expect(prefs.minute, notificationService.lastMinute);
  });

  testWidgets('shows the feedback toggle on by default', (tester) async {
    await pumpSettings(tester);

    expect(find.text('着手の効果音・バイブ'), findsOneWidget);
    expect(find.text('オン'), findsOneWidget);
  });

  testWidgets('loads a previously-disabled feedback setting', (tester) async {
    final feedbackPrefs = _FakeSoundFeedbackPreferences(enabled: false);
    await pumpSettings(tester, soundFeedbackPreferences: feedbackPrefs);

    expect(
      find.descendant(
        of: find.widgetWithIcon(SwitchListTile, Icons.volume_up_outlined),
        matching: find.text('オフ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('toggling feedback off persists it and updates the global flag', (
    tester,
  ) async {
    final feedbackPrefs = _FakeSoundFeedbackPreferences();
    await pumpSettings(tester, soundFeedbackPreferences: feedbackPrefs);

    await tester.tap(find.widgetWithIcon(SwitchListTile, Icons.volume_up_outlined));
    await tester.pumpAndSettle();

    expect(feedbackPrefs.enabled, isFalse);
    expect(reversiaFeedbackEnabled, isFalse);
    expect(
      find.descendant(
        of: find.widgetWithIcon(SwitchListTile, Icons.volume_up_outlined),
        matching: find.text('オフ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the saved avatar emoji and label', (tester) async {
    await pumpSettings(
      tester,
      avatarPreferences: _FakeAvatarPreferences(avatar: ReversiaAvatar.byId('fox')),
    );

    expect(find.text('🦊'), findsOneWidget);
    expect(find.text('フォックス'), findsOneWidget);
  });

  testWidgets('picking a new avatar persists it and updates the tile', (tester) async {
    final avatarPrefs = _FakeAvatarPreferences();
    await pumpSettings(tester, avatarPreferences: avatarPrefs);

    await tester.tap(find.text('アバター'));
    await tester.pumpAndSettle();

    expect(find.text('🐉  ドラゴン'), findsOneWidget);
    await tester.tap(find.text('🐉  ドラゴン'));
    await tester.pumpAndSettle();

    expect(avatarPrefs.avatar.id, 'dragon');
    expect(find.text('ドラゴン'), findsOneWidget);
  });
}
