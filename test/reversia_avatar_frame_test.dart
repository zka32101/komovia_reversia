import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/l10n/app_localizations.dart';
import 'package:komovia_reversia/models/reversia_game_stats.dart';
import 'package:komovia_reversia/services/avatar_frame_preferences.dart';
import 'package:komovia_reversia/services/avatar_preferences.dart';
import 'package:komovia_reversia/services/daily_reminder_preferences.dart';
import 'package:komovia_reversia/services/sound_feedback_preferences.dart';
import 'package:komovia_reversia/src/reversia_avatar.dart';
import 'package:komovia_reversia/src/reversia_avatar_frame.dart';
import 'package:komovia_reversia/views/screens/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReversiaGameStats _stats({int games = 0, int wins = 0, int streak = 0}) => ReversiaGameStats(
      totalGames: games,
      wins: wins,
      losses: games - wins,
      draws: 0,
      currentWinStreak: 0,
      longestWinStreak: streak,
    );

class _NoopNotifications implements LocalNotificationServiceLike {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {}
  @override
  Future<void> cancelDailyReminder() async {}
}

class _MemFramePrefs implements AvatarFramePreferencesLike {
  _MemFramePrefs([this.id]);
  String? id;
  @override
  Future<String?> getFrameId() async => id;
  @override
  Future<void> setFrameId(String? frameId) async => id = frameId;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('catalog', () {
    test('has unique ids spanning bronze to platinum', () {
      final ids = ReversiaAvatarFrame.all.map((f) => f.id).toSet();
      expect(ids.length, ReversiaAvatarFrame.all.length);
      expect(ReversiaAvatarFrame.all.length, inInclusiveRange(6, 10));
      expect(ReversiaAvatarFrame.all.map((f) => f.frame.tier).toSet(), FrameTier.values.toSet());
    });

    test('byId resolves known ids and returns null otherwise', () {
      expect(ReversiaAvatarFrame.byId('first_win')!.frame.tier, FrameTier.bronze);
      expect(ReversiaAvatarFrame.byId(null), isNull);
      expect(ReversiaAvatarFrame.byId('nope'), isNull);
    });
  });

  group('unlock logic', () {
    test('nothing unlocked with no games', () {
      expect(ReversiaAvatarFrame.unlockedIds(ReversiaGameStats.initial), isEmpty);
    });

    test('unlocks by games, wins and longest streak thresholds', () {
      expect(ReversiaAvatarFrame.unlockedIds(_stats(games: 1)), {'first_game'});
      expect(ReversiaAvatarFrame.unlockedIds(_stats(games: 10, wins: 1)),
          {'first_game', 'first_win', 'games_10'});
      expect(ReversiaAvatarFrame.unlockedIds(_stats(games: 60, wins: 50, streak: 10)),
          ReversiaAvatarFrame.all.map((f) => f.id).toSet());
      expect(ReversiaAvatarFrame.unlockedIds(_stats(games: 5, wins: 3, streak: 3)),
          contains('streak_3'));
    });

    test('resolveSelected falls back to no frame when locked or unknown', () {
      expect(ReversiaAvatarFrame.resolveSelected('wins_50', _stats(games: 5, wins: 5)), isNull);
      expect(ReversiaAvatarFrame.resolveSelected('gone', _stats(games: 5)), isNull);
      expect(ReversiaAvatarFrame.resolveSelected(null, _stats(games: 5)), isNull);
      expect(ReversiaAvatarFrame.resolveSelected('first_game', _stats(games: 1))!.id, 'first_game');
    });
  });

  group('AvatarFramePreferences', () {
    test('persists, reloads and clears', () async {
      final prefs = AvatarFramePreferences();
      expect(await prefs.getFrameId(), isNull);
      await prefs.setFrameId('games_10');
      expect(await prefs.getFrameId(), 'games_10');
      await prefs.setFrameId(null);
      expect(await prefs.getFrameId(), isNull);
    });
  });

  group('FramedAvatar rendering', () {
    Future<BoxDecoration> pumpAndGetDecoration(WidgetTester tester, ReversiaAvatarFrame? f) async {
      await tester.pumpWidget(MaterialApp(home: FramedAvatar(emoji: '🐧', frame: f)));
      final c = tester.widget<Container>(find.byKey(const ValueKey('framed-avatar')));
      return c.decoration! as BoxDecoration;
    }

    testWidgets('draws a tier-colored border for a frame', (tester) async {
      final f = ReversiaAvatarFrame.byId('streak_10')!;
      final d = await pumpAndGetDecoration(tester, f);
      expect((d.border! as Border).top.color, ReversiaAvatarFrame.tierColor(FrameTier.platinum));
    });

    testWidgets('falls back to no border without a frame', (tester) async {
      final d = await pumpAndGetDecoration(tester, null);
      expect(d.border, isNull);
    });
  });

  group('settings picker', () {
    Future<void> pump(WidgetTester tester, ReversiaGameStats stats, _MemFramePrefs prefs) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: SettingsScreen(
            uid: 'u1',
            notificationService: _NoopNotifications(),
            preferences: DailyReminderPreferences(),
            soundFeedbackPreferences: SoundFeedbackPreferences(),
            avatarPreferences: AvatarPreferences(),
            framePreferences: prefs,
            statsLoader: (_) async => stats,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows locked frames with requirement and selects an unlocked one',
        (tester) async {
      final prefs = _MemFramePrefs();
      await pump(tester, _stats(games: 2, wins: 1), prefs);
      expect(find.text('フレームなし'), findsOneWidget);
      await tester.tap(find.text('アバターフレーム'));
      await tester.pumpAndSettle();

      expect(find.text('AI対局で10連勝'), findsOneWidget);
      expect(find.text('AI対局を50局プレイ'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(6));

      await tester.tap(find.text('初勝利'));
      await tester.pumpAndSettle();
      expect(prefs.id, 'first_win');
      expect(find.text('初勝利'), findsOneWidget);
      final c = tester.widget<Container>(find.byKey(const ValueKey('framed-avatar')).first);
      expect(((c.decoration! as BoxDecoration).border! as Border).top.color,
          ReversiaAvatarFrame.tierColor(FrameTier.bronze));
    });

    testWidgets('a saved but now-locked frame renders as no frame', (tester) async {
      await pump(tester, ReversiaGameStats.initial, _MemFramePrefs('streak_10'));
      expect(find.text('フレームなし'), findsOneWidget);
      expect(ReversiaAvatar.defaultAvatar.emoji, '🐧');
    });
  });
}
