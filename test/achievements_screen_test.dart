import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/achievement_service.dart';
import 'package:komovia_reversia/services/leaderboard_service.dart';
import 'package:komovia_reversia/viewmodels/achievement_provider.dart';
import 'package:komovia_reversia/viewmodels/leaderboard_provider.dart';
import 'package:komovia_reversia/views/screens/achievements_screen.dart';

void main() {
  Future<AchievementService> pumpScreen(
    WidgetTester tester, {
    String uid = 'u1',
  }) async {
    final firestore = FakeFirebaseFirestore();
    final leaderboard = LeaderboardService(firestore: firestore);
    final service = AchievementService(firestore: firestore, leaderboard: leaderboard);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardServiceProvider.overrideWithValue(leaderboard),
          achievementServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(home: AchievementsScreen(uid: uid)),
      ),
    );
    await tester.pump();
    await tester.pump();
    return service;
  }

  testWidgets('lists every achievement definition', (tester) async {
    await pumpScreen(tester);

    for (final def in AchievementService.definitions) {
      expect(find.text(def.name), findsOneWidget);
    }
  });

  testWidgets('shows a lock icon and progress for a locked achievement', (tester) async {
    await pumpScreen(tester);

    expect(find.byIcon(Icons.lock), findsWidgets);
    expect(find.textContaining('/'), findsWidgets);
  });

  testWidgets('shows a check icon instead of a progress bar once unlocked', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final leaderboard = LeaderboardService(firestore: firestore);
    final service = AchievementService(firestore: firestore, leaderboard: leaderboard);
    await service.unlockAchievement('u1', 'first_win');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardServiceProvider.overrideWithValue(leaderboard),
          achievementServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AchievementsScreen(uid: 'u1')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
