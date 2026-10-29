import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/tournament_service.dart';
import 'package:komovia_reversia/viewmodels/tournament_provider.dart';
import 'package:komovia_reversia/views/screens/tournament_bracket_screen.dart';
import 'package:komovia_reversia/views/screens/tournament_screen.dart';

void main() {
  Future<TournamentService> pumpScreen(
    WidgetTester tester, {
    String uid = 'u1',
  }) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tournamentServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: TournamentScreen(uid: uid, displayName: 'Alice'),
        ),
      ),
    );
    await tester.pump();
    return service;
  }

  testWidgets('shows an empty state with no tournaments', (tester) async {
    await pumpScreen(tester);

    expect(find.text('まだトーナメントはありません'), findsOneWidget);
  });

  testWidgets('lists a tournament and shows a join button for a non-participant', (
    tester,
  ) async {
    final service = await pumpScreen(tester, uid: 'u2');
    await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Test Cup'), findsOneWidget);
    expect(find.text('参加する'), findsOneWidget);
  });

  testWidgets('hides the join button once already a participant', (tester) async {
    final service = await pumpScreen(tester, uid: 'u1');
    await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('参加する'), findsNothing);
  });

  testWidgets('tapping 参加する joins the tournament', (tester) async {
    final service = await pumpScreen(tester, uid: 'u2');
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('参加する'));
    await tester.pump();

    final loaded = await service.getTournament(t.id);
    expect(loaded!.participantUids, contains('u2'));
  });

  testWidgets('tapping a tournament opens TournamentBracketScreen', (tester) async {
    final service = await pumpScreen(tester);
    await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Test Cup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TournamentBracketScreen), findsOneWidget);
  });

  testWidgets('creating a tournament via the dialog persists it', (tester) async {
    final service = await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New Cup');
    await tester.tap(find.text('作成'));
    await tester.pump();
    await tester.pump();

    final tournaments = await service.tournamentsStream().first;
    expect(tournaments, hasLength(1));
    expect(tournaments.first.name, 'New Cup');
  });
}
