import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/leaderboard_service.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';
import 'package:komovia_reversia/viewmodels/index.dart';

void main() {
  group('resignReversiaPvpGameProvider rating update', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late LeaderboardService leaderboardService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      leaderboardService = LeaderboardService(firestore: firestore);
      container = ProviderContainer(overrides: [
        reversiaPvpGameServiceProvider
            .overrideWithValue(ReversiaPvpGameService(firestore)),
        leaderboardServiceProvider.overrideWithValue(leaderboardService),
      ]);
    });

    tearDown(() => container.dispose());

    test('resignation raises the winner\'s rating and lowers the loser\'s',
        () async {
      final game = await container.read(createReversiaPvpGameProvider)(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );

      await container.read(resignReversiaPvpGameProvider)(game.id, 'u1');

      final winnerEntry = await leaderboardService.getEntry('u2');
      final loserEntry = await leaderboardService.getEntry('u1');
      expect(winnerEntry, isNotNull);
      expect(loserEntry, isNotNull);
      expect(winnerEntry!.rating, greaterThan(1200));
      expect(loserEntry!.rating, lessThan(1200));
      expect(winnerEntry.gamesPlayed, 1);
      expect(winnerEntry.wins, 1);
      expect(loserEntry.gamesPlayed, 1);
      expect(loserEntry.wins, 0);
    });

    test('a non-existent game is a no-op (no leaderboard writes)', () async {
      await container.read(resignReversiaPvpGameProvider)('no-such-game', 'u1');

      expect(await leaderboardService.getEntry('u1'), isNull);
    });
  });
}
