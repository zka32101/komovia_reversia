import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/services/tournament_service.dart';
import 'package:komovia_reversia/viewmodels/auth_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_pvp_game_provider.dart';
import 'package:komovia_reversia/viewmodels/tournament_provider.dart';
import 'package:komovia_reversia/views/screens/reversia_pvp_game_screen.dart';
import 'package:komovia_reversia/views/screens/tournament_bracket_screen.dart';

void main() {
  Future<void> pumpBracket(
    WidgetTester tester, {
    required String tournamentId,
    String uid = 'u1',
    String displayName = 'Alice',
    required TournamentService service,
    ReversiaPvpGameService? pvpService,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tournamentServiceProvider.overrideWithValue(service),
          currentUidProvider.overrideWithValue(uid),
          if (pvpService != null)
            reversiaPvpGameServiceProvider.overrideWithValue(pvpService),
        ],
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

  testWidgets(
      'a participant can start the match, play it, and the result reports back to the tournament',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.startTournament(t.id, {'u1': 'Alice', 'u2': 'Bob'});

    await pumpBracket(
      tester,
      tournamentId: t.id,
      uid: 'u1',
      service: service,
      pvpService: pvpService,
    );
    expect(find.text('対局を開始する'), findsOneWidget);

    await tester.tap(find.text('対局を開始する'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);

    // 自分(u1)が投了すると、対局終局フック(resignReversiaPvpGameProvider)
    // が自動的にトーナメント結果を報告する - 自己申告ではなく実際の対局
    // 結果で決まる。
    await tester.tap(find.text('投了する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投了する').last);
    await tester.pumpAndSettle();

    final tournament = await service.getTournament(t.id);
    expect(tournament!.isCompleted, isTrue);
    expect(tournament.winnerId, 'u2');
  });

  testWidgets('shows a bye as a completed match with no start/watch button', (tester) async {
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
    expect(find.text('対局を開始する'), findsNothing);
    expect(find.text('対局を見る'), findsNothing);
  });

  testWidgets('shows 対局を見る once a match has a game, even for a non-participant', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = TournamentService(firestore: firestore);
    final pvpService = ReversiaPvpGameService(firestore);
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.startTournament(t.id, {'u1': 'Alice', 'u2': 'Bob'});
    final match = (await service.matchesStream(t.id).first).single;
    await pvpService.createGameForTournamentMatch(
      tournamentId: t.id,
      matchId: match.id,
      firstUid: 'u1',
      firstDisplayName: 'Alice',
      secondUid: 'u2',
      secondDisplayName: 'Bob',
    );

    await pumpBracket(
      tester,
      tournamentId: t.id,
      uid: 'spectator',
      service: service,
      pvpService: pvpService,
    );

    expect(find.text('対局を見る'), findsOneWidget);
    expect(find.text('対局を開始する'), findsNothing);

    await tester.tap(find.text('対局を見る'));
    await tester.pumpAndSettle();

    expect(find.byType(ReversiaPvpGameScreen), findsOneWidget);
  });
}
