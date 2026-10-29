import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_weekly_progress_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_weekly_progress_provider.dart';
import 'package:komovia_reversia/views/screens/reversia_weekly_goals_screen.dart';

void main() {
  Future<ReversiaWeeklyProgressService> pumpScreen(
    WidgetTester tester, {
    String? uid = 'u1',
  }) async {
    final firestore = FakeFirebaseFirestore();
    final service = ReversiaWeeklyProgressService(firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue(uid),
          reversiaWeeklyProgressServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: ReversiaWeeklyGoalsScreen()),
      ),
    );
    await tester.pump();
    return service;
  }

  testWidgets('shows all three goals at 0 progress initially', (tester) async {
    await pumpScreen(tester);

    expect(find.text('今週3局プレイ'), findsOneWidget);
    expect(find.text('今週2勝'), findsOneWidget);
    expect(find.text('今週パズルを3日解く'), findsOneWidget);
    expect(find.text('0 / 3'), findsNWidgets(2));
    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets('shows a checkmark once a goal is completed', (tester) async {
    final service = await pumpScreen(tester);
    await service.recordGamePlayed(uid: 'u1', won: true);
    await service.recordGamePlayed(uid: 'u1', won: true);
    await tester.pump();
    await tester.pump();

    final winGoalCard = find.ancestor(
      of: find.text('今週2勝'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: winGoalCard, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
  });

  testWidgets('shows the goals at zero progress while signed out', (tester) async {
    await pumpScreen(tester, uid: null);

    expect(find.text('今週3局プレイ'), findsOneWidget);
    expect(find.text('0 / 3'), findsNWidgets(2));
  });
}
