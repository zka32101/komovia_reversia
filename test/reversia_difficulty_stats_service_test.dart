import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_difficulty_stats_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReversiaDifficultyStatsService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ReversiaDifficultyStatsService(firestore);
  });

  test('getStats returns zeroed stats when nothing was ever recorded', () async {
    final stats = await service.getStats('u1');
    expect(stats.statsFor(1).games, 0);
    expect(stats.statsFor(2).games, 0);
    expect(stats.statsFor(3).games, 0);
  });

  test('recordGame increments games for the played level only', () async {
    await service.recordGame(uid: 'u1', level: 2, won: true);
    await service.recordGame(uid: 'u1', level: 2, won: false);
    await service.recordGame(uid: 'u1', level: 1, won: true);

    final stats = await service.getStats('u1');
    expect(stats.statsFor(2).games, 2);
    expect(stats.statsFor(2).wins, 1);
    expect(stats.statsFor(1).games, 1);
    expect(stats.statsFor(1).wins, 1);
    expect(stats.statsFor(3).games, 0);
  });

  test('stats are tracked independently per uid', () async {
    await service.recordGame(uid: 'u1', level: 2, won: true);
    final other = await service.getStats('u2');
    expect(other.statsFor(2).games, 0);
  });

  test('watchStats streams the initial value, then updates after a write', () async {
    final before = await service.watchStats('u1').first;
    expect(before.statsFor(2).games, 0);

    await service.recordGame(uid: 'u1', level: 2, won: true);
    await Future<void>.delayed(Duration.zero);

    final after = await service.watchStats('u1').first;
    expect(after.statsFor(2).games, 1);
  });
}
