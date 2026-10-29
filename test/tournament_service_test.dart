import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/tournament_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TournamentService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TournamentService(firestore: firestore);
  });

  test('createTournament persists it as upcoming with the creator as the sole participant', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );

    expect(t.status, 'upcoming');
    expect(t.participantUids, ['u1']);
    expect(t.createdBy, 'u1');

    final loaded = await service.getTournament(t.id);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Test Cup');
  });

  test('joinTournament adds the uid without duplicating it', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );

    await service.joinTournament(t.id, 'u2');
    await service.joinTournament(t.id, 'u2');

    final loaded = await service.getTournament(t.id);
    expect(loaded!.participantUids, ['u1', 'u2']);
  });

  test('startTournament refuses an unsupported format', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
      format: 'ladder',
    );

    expect(
      () => service.startTournament(t.id, {}),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('startTournament with an even participant count pairs everyone with no byes', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.joinTournament(t.id, 'u3');
    await service.joinTournament(t.id, 'u4');

    await service.startTournament(t.id, {
      'u1': 'Alice',
      'u2': 'Bob',
      'u3': 'Carol',
      'u4': 'Dave',
    });

    final tournament = await service.getTournament(t.id);
    expect(tournament!.isActive, isTrue);

    final matches = await service.matchesStream(t.id).first;
    expect(matches, hasLength(2));
    expect(matches.every((m) => !m.isBye), isTrue);
    expect(matches.every((m) => m.round == 1), isTrue);
  });

  test('startTournament with an odd participant count gives one player a completed bye', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.joinTournament(t.id, 'u3');

    await service.startTournament(t.id, {
      'u1': 'Alice',
      'u2': 'Bob',
      'u3': 'Carol',
    });

    final matches = await service.matchesStream(t.id).first;
    expect(matches, hasLength(2));
    final bye = matches.where((m) => m.isBye).single;
    expect(bye.isCompleted, isTrue);
    expect(bye.winnerUid, bye.player1Uid);
  });

  test('startTournament is a no-op once the tournament is no longer upcoming', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.startTournament(t.id, {'u1': 'Alice', 'u2': 'Bob'});

    await service.startTournament(t.id, {'u1': 'Alice', 'u2': 'Bob'});

    final matches = await service.matchesStream(t.id).first;
    expect(matches, hasLength(1));
  });

  test('recordMatchResult advances to the next round once the round completes', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.joinTournament(t.id, 'u3');
    await service.joinTournament(t.id, 'u4');
    final displayNames = {
      'u1': 'Alice',
      'u2': 'Bob',
      'u3': 'Carol',
      'u4': 'Dave',
    };
    await service.startTournament(t.id, displayNames);

    final round1 = await service.matchesStream(t.id).first;
    for (final m in round1) {
      await service.recordMatchResult(t.id, m.id, m.player1Uid!, displayNames);
    }

    final matches = await service.matchesStream(t.id).first;
    expect(matches.where((m) => m.round == 2), hasLength(1));

    final tournament = await service.getTournament(t.id);
    expect(tournament!.isActive, isTrue);
  });

  test('recordMatchResult completes the tournament once only one winner remains', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    final displayNames = {'u1': 'Alice', 'u2': 'Bob'};
    await service.startTournament(t.id, displayNames);

    final round1 = await service.matchesStream(t.id).first;
    await service.recordMatchResult(t.id, round1.first.id, 'u1', displayNames);

    final tournament = await service.getTournament(t.id);
    expect(tournament!.isCompleted, isTrue);
    expect(tournament.winnerId, 'u1');
  });

  test('recordMatchResult never double-advances when a round\'s matches finish out of order twice', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
    );
    await service.joinTournament(t.id, 'u2');
    await service.joinTournament(t.id, 'u3');
    await service.joinTournament(t.id, 'u4');
    final displayNames = {
      'u1': 'Alice',
      'u2': 'Bob',
      'u3': 'Carol',
      'u4': 'Dave',
    };
    await service.startTournament(t.id, displayNames);
    final round1 = await service.matchesStream(t.id).first;

    await service.recordMatchResult(t.id, round1[0].id, round1[0].player1Uid!, displayNames);
    await service.recordMatchResult(t.id, round1[1].id, round1[1].player1Uid!, displayNames);
    // A duplicate call (e.g. a retried write) re-marks the same match
    // complete and re-triggers the advance check - it must not generate a
    // second round-2 bracket.
    await service.recordMatchResult(t.id, round1[0].id, round1[0].player1Uid!, displayNames);

    final matches = await service.matchesStream(t.id).first;
    expect(matches.where((m) => m.round == 2), hasLength(1));
  });

  group('round_robin', () {
    test('startTournament generates every pairing across n-1 rounds for an even count', () async {
      final t = await service.createTournament(
        name: 'RR Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'round_robin',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      await service.joinTournament(t.id, 'u4');
      final displayNames = {
        'u1': 'Alice',
        'u2': 'Bob',
        'u3': 'Carol',
        'u4': 'Dave',
      };

      await service.startTournament(t.id, displayNames);

      final tournament = await service.getTournament(t.id);
      expect(tournament!.isActive, isTrue);

      final matches = await service.matchesStream(t.id).first;
      // 4人なら3節×2試合=6試合が一度に全部生成される。
      expect(matches, hasLength(6));
      expect(matches.map((m) => m.round).toSet(), {1, 2, 3});
      final pairKeys = matches
          .map((m) => ([m.player1Uid, m.player2Uid]..sort()).join('|'))
          .toSet();
      expect(pairKeys, hasLength(6)); // 全ペアが互いに一度ずつ当たる
    });

    test('an odd participant count leaves one bye slot per round with no match document', () async {
      final t = await service.createTournament(
        name: 'RR Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'round_robin',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      final displayNames = {'u1': 'Alice', 'u2': 'Bob', 'u3': 'Carol'};

      await service.startTournament(t.id, displayNames);

      final matches = await service.matchesStream(t.id).first;
      // 3人なら3節×1試合=3試合(各節1人は休み、休みには試合は作らない)。
      expect(matches, hasLength(3));
      expect(matches.every((m) => !m.isBye), isTrue);
    });

    test('recordMatchResult completes the tournament once every match is done, winner by most wins', () async {
      final t = await service.createTournament(
        name: 'RR Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'round_robin',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      final displayNames = {'u1': 'Alice', 'u2': 'Bob', 'u3': 'Carol'};
      await service.startTournament(t.id, displayNames);

      // u1がすべて勝つようにする。
      var matches = await service.matchesStream(t.id).first;
      for (final m in matches) {
        final winner = m.player1Uid == 'u1' || m.player2Uid == 'u1'
            ? 'u1'
            : m.player1Uid!;
        await service.recordMatchResult(t.id, m.id, winner, displayNames);
      }

      final tournament = await service.getTournament(t.id);
      expect(tournament!.isCompleted, isTrue);
      expect(tournament.winnerId, 'u1');

      final standings = await service.getStandings(t.id);
      expect(standings.first.uid, 'u1');
      expect(standings.first.wins, 2);
    });

    test('recordMatchResult does not re-complete an already-completed tournament', () async {
      final t = await service.createTournament(
        name: 'RR Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'round_robin',
      );
      await service.joinTournament(t.id, 'u2');
      final displayNames = {'u1': 'Alice', 'u2': 'Bob'};
      await service.startTournament(t.id, displayNames);

      final matches = await service.matchesStream(t.id).first;
      await service.recordMatchResult(t.id, matches.single.id, 'u1', displayNames);
      // 同じ結果を再度記録しても問題なく完了済みのまま。
      await service.recordMatchResult(t.id, matches.single.id, 'u1', displayNames);

      final tournament = await service.getTournament(t.id);
      expect(tournament!.isCompleted, isTrue);
      expect(tournament.winnerId, 'u1');
    });
  });

  group('swiss', () {
    test('startTournament computes totalRounds and generates round 1 with no byes for an even count', () async {
      final t = await service.createTournament(
        name: 'Swiss Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'swiss',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      await service.joinTournament(t.id, 'u4');
      final displayNames = {
        'u1': 'Alice',
        'u2': 'Bob',
        'u3': 'Carol',
        'u4': 'Dave',
      };

      await service.startTournament(t.id, displayNames);

      final tournament = await service.getTournament(t.id);
      expect(tournament!.isActive, isTrue);
      expect(tournament.totalRounds, 3); // max(3, ceil(log2(4))) == 3

      final matches = await service.matchesStream(t.id).first;
      expect(matches, hasLength(2));
      expect(matches.every((m) => !m.isBye && m.round == 1), isTrue);
    });

    test('an odd participant count gives one player a completed bye each round', () async {
      final t = await service.createTournament(
        name: 'Swiss Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'swiss',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      final displayNames = {'u1': 'Alice', 'u2': 'Bob', 'u3': 'Carol'};

      await service.startTournament(t.id, displayNames);

      final matches = await service.matchesStream(t.id).first;
      final bye = matches.where((m) => m.isBye).single;
      expect(bye.isCompleted, isTrue);
      expect(bye.winnerUid, bye.player1Uid);
    });

    test('recordMatchResult advances to the next round once the round completes', () async {
      final t = await service.createTournament(
        name: 'Swiss Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'swiss',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      await service.joinTournament(t.id, 'u4');
      final displayNames = {
        'u1': 'Alice',
        'u2': 'Bob',
        'u3': 'Carol',
        'u4': 'Dave',
      };
      await service.startTournament(t.id, displayNames);

      final round1 = await service.matchesStream(t.id).first;
      for (final m in round1) {
        await service.recordMatchResult(t.id, m.id, m.player1Uid!, displayNames);
      }

      final matches = await service.matchesStream(t.id).first;
      expect(matches.where((m) => m.round == 2), hasLength(2));

      final tournament = await service.getTournament(t.id);
      expect(tournament!.isActive, isTrue);
      expect(tournament.lastAdvancedRound, 1);
    });

    test('completes the tournament once the final round finishes, winner by most wins', () async {
      final t = await service.createTournament(
        name: 'Swiss Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'swiss',
      );
      await service.joinTournament(t.id, 'u2');
      final displayNames = {'u1': 'Alice', 'u2': 'Bob'};
      await service.startTournament(t.id, displayNames);

      final tournament0 = await service.getTournament(t.id);
      expect(tournament0!.totalRounds, 3); // max(3, ceil(log2(2))) == 3

      for (var round = 1; round <= 3; round++) {
        final current = (await service.matchesStream(t.id).first)
            .where((m) => m.round == round && !m.isCompleted)
            .toList();
        for (final m in current) {
          await service.recordMatchResult(t.id, m.id, 'u1', displayNames);
        }
      }

      final tournament = await service.getTournament(t.id);
      expect(tournament!.isCompleted, isTrue);
      expect(tournament.winnerId, 'u1');
    });

    test('never double-advances when a round\'s matches finish out of order twice', () async {
      final t = await service.createTournament(
        name: 'Swiss Cup',
        description: '',
        createdBy: 'u1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        format: 'swiss',
      );
      await service.joinTournament(t.id, 'u2');
      await service.joinTournament(t.id, 'u3');
      await service.joinTournament(t.id, 'u4');
      final displayNames = {
        'u1': 'Alice',
        'u2': 'Bob',
        'u3': 'Carol',
        'u4': 'Dave',
      };
      await service.startTournament(t.id, displayNames);
      final round1 = await service.matchesStream(t.id).first;

      await service.recordMatchResult(t.id, round1[0].id, round1[0].player1Uid!, displayNames);
      await service.recordMatchResult(t.id, round1[1].id, round1[1].player1Uid!, displayNames);
      await service.recordMatchResult(t.id, round1[0].id, round1[0].player1Uid!, displayNames);

      final matches = await service.matchesStream(t.id).first;
      expect(matches.where((m) => m.round == 2), hasLength(2));
    });
  });
}
