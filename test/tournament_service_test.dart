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

  test('startTournament refuses a non-single_elimination format', () async {
    final t = await service.createTournament(
      name: 'Test Cup',
      description: '',
      createdBy: 'u1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 8),
      format: 'round_robin',
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
}
