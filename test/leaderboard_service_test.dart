import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/services/leaderboard_service.dart';

void main() {
  group('LeaderboardService', () {
    test('incrementStats creates a default entry at rating 1200 on first call',
        () async {
      final service = LeaderboardService(firestore: FakeFirebaseFirestore());
      await service.incrementStats(
        uid: 'u1',
        displayName: 'Alice',
        ratingDelta: 16,
        gamesDelta: 1,
        winsDelta: 1,
      );

      final entry = await service.getEntry('u1');
      expect(entry, isNotNull);
      expect(entry!.rating, 1216);
      expect(entry.gamesPlayed, 1);
      expect(entry.wins, 1);
      expect(entry.winRate, 1.0);
    });

    test('incrementStats accumulates across multiple calls', () async {
      final service = LeaderboardService(firestore: FakeFirebaseFirestore());
      await service.incrementStats(
        uid: 'u1',
        displayName: 'Alice',
        ratingDelta: 16,
        gamesDelta: 1,
        winsDelta: 1,
      );
      await service.incrementStats(
        uid: 'u1',
        displayName: 'Alice',
        ratingDelta: -10,
        gamesDelta: 1,
        winsDelta: 0,
      );

      final entry = await service.getEntry('u1');
      expect(entry!.rating, 1206);
      expect(entry.gamesPlayed, 2);
      expect(entry.wins, 1);
      expect(entry.winRate, 0.5);
    });

    test('getEntry returns null for an unknown uid', () async {
      final service = LeaderboardService(firestore: FakeFirebaseFirestore());
      expect(await service.getEntry('nobody'), isNull);
    });

    test('topEntriesStream orders by rating descending', () async {
      final service = LeaderboardService(firestore: FakeFirebaseFirestore());
      await service.updateEntry(
        LeaderboardEntry(
          uid: 'low',
          displayName: 'Low',
          rank: 0,
          rating: 1000,
          gamesPlayed: 1,
          wins: 0,
          winRate: 0,
          puzzlesSolved: 0,
          lastUpdated: DateTime.now(),
        ),
      );
      await service.updateEntry(
        LeaderboardEntry(
          uid: 'high',
          displayName: 'High',
          rank: 0,
          rating: 1500,
          gamesPlayed: 1,
          wins: 1,
          winRate: 1,
          puzzlesSolved: 0,
          lastUpdated: DateTime.now(),
        ),
      );

      final top = await service.topEntriesStream().first;
      expect(top.map((e) => e.uid).toList(), ['high', 'low']);
    });
  });
}
