import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/tournament_service.dart';
import 'package:komovia_reversia/viewmodels/tournament_provider.dart';
import 'package:komovia_reversia/views/screens/tournament_bracket_screen.dart';

void main() {
  Future<void> pumpBracket(
    WidgetTester tester, {
    required String tournamentId,
    String uid = 'u1',
    String displayName = 'Alice',
    required TournamentService service,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tournamentServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: TournamentBracketScreen(
            tournamentId: tournamentId,
            uid: uid,
            displayName: displayName,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('shows a not-generated-yet message before the bracket starts', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );

    await pumpBracket(tester, tournamentId: t.id, service: service);

    expect(find.text('まだブラケットは生成されていません'), findsOneWidget);
    expect(find.text('開始する'), findsOneWidget);
  });

  testWidgets('starting the tournament generates and shows round 1', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');

    await pumpBracket(tester, tournamentId: t.id, service: service);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('1回戦'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a participant can report their own win, advancing the match', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.startTournament(t.id, {'u1': 'Alice', 'u2': 'Bob'});

    await pumpBracket(tester, tournamentId: t.id, uid: 'u1', service: service);
    expect(find.text('勝ちを報告する'), findsOneWidget);

    await tester.tap(find.text('勝ちを報告する'));
    await tester.pump();
    await tester.pump();

    final tournament = await service.getTournament(t.id);
    expect(tournament!.isCompleted, isTrue);
    expect(tournament.winnerId, 'u1');
  });

  testWidgets('shows a bye as a completed match with no report button', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.startTournament(t.id, {'u1': 'Alice'});

    await pumpBracket(tester, tournamentId: t.id, service: service);
    await tester.pumpAndSettle();

    expect(find.textContaining('不戦勝'), findsOneWidget);
    expect(find.text('勝ちを報告する'), findsNothing);
  });
}
