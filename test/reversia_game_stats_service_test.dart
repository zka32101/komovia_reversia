import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_game_stats_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReversiaGameStatsService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ReversiaGameStatsService(firestore: firestore);
  });

  test('getStats returns the zeroed initial stats before any game', () async {
    final stats = await service.getStats('u1');
    expect(stats.totalGames, 0);
    expect(stats.wins, 0);
    expect(stats.losses, 0);
    expect(stats.draws, 0);
    expect(stats.currentWinStreak, 0);
    expect(stats.longestWinStreak, 0);
  });

  test('a win increments wins, totalGames, and both streak counters', () async {
    await service.recordGameResult(uid: 'u1', won: true);

    final stats = await service.getStats('u1');
    expect(stats.totalGames, 1);
    expect(stats.wins, 1);
    expect(stats.currentWinStreak, 1);
    expect(stats.longestWinStreak, 1);
  });

  test('a loss increments losses and resets the current win streak', () async {
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u1', won: false);

    final stats = await service.getStats('u1');
    expect(stats.totalGames, 3);
    expect(stats.wins, 2);
    expect(stats.losses, 1);
    expect(stats.currentWinStreak, 0);
    expect(stats.longestWinStreak, 2);
  });

  test('a draw increments draws, is not a loss, and resets the win streak', () async {
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u1', won: false, draw: true);

    final stats = await service.getStats('u1');
    expect(stats.totalGames, 2);
    expect(stats.wins, 1);
    expect(stats.losses, 0);
    expect(stats.draws, 1);
    expect(stats.currentWinStreak, 0);
  });

  test('longestWinStreak keeps the historical peak after the streak ends', () async {
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u1', won: false);
    await service.recordGameResult(uid: 'u1', won: true);

    final stats = await service.getStats('u1');
    expect(stats.currentWinStreak, 1);
    expect(stats.longestWinStreak, 3);
  });

  test('watchStats streams the zeroed initial stats and updates after a win', () async {
    final first = await service.watchStats('u1').first;
    expect(first.totalGames, 0);

    await service.recordGameResult(uid: 'u1', won: true);
    await Future<void>.delayed(Duration.zero);
    final updated = await service.watchStats('u1').first;
    expect(updated.totalGames, 1);
    expect(updated.wins, 1);
  });

  test('stats are tracked independently per uid', () async {
    await service.recordGameResult(uid: 'u1', won: true);
    await service.recordGameResult(uid: 'u2', won: false);

    final stats1 = await service.getStats('u1');
    final stats2 = await service.getStats('u2');
    expect(stats1.wins, 1);
    expect(stats2.losses, 1);
  });
}
