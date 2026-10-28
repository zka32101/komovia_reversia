import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/services/reversia_pvp_game_service.dart';

void main() {
  group('ReversiaPvpGameService', () {
    test('createGame persists an active game with Side.first to move',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);

      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
        matchId: 'm1',
      );

      expect(game.status, 'active');
      expect(game.isFirstTurn, isTrue);
      expect(game.movesCount, 0);
      expect(game.movesRecord, '');
      final fetched = await service.getGame(game.id);
      expect(fetched, isNotNull);
      expect(fetched!.firstUid, 'u1');
      expect(fetched.matchId, 'm1');
    });

    test('applyMove rejects a move from the player whose turn it is not',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );
      final reversiaGame = ReversiaGame();
      final firstLegal =
          reversiaGame.legalMoves(reversiaGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u2', // it's Side.first's (u1's) turn, not Side.second's
        move: firstLegal,
      );

      expect(applied, isFalse);
      final fetched = await service.getGame(game.id);
      expect(fetched!.movesCount, 0);
    });

    test('applyMove rejects a non-participant', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );
      final reversiaGame = ReversiaGame();
      final firstLegal =
          reversiaGame.legalMoves(reversiaGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'nobody',
        move: firstLegal,
      );

      expect(applied, isFalse);
    });

    test('applyMove rejects an illegal move', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );

      // A1 to A1 is never a legal move for anyone.
      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u1',
        move: const BoardMove(from: Square(0, 0), to: Square(0, 0)),
      );

      expect(applied, isFalse);
    });

    test(
        'applyMove updates movesRecord, flips the turn, and increments movesCount',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );
      final reversiaGame = ReversiaGame();
      final firstLegal =
          reversiaGame.legalMoves(reversiaGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u1',
        move: firstLegal,
      );

      expect(applied, isTrue);
      final fetched = await service.getGame(game.id);
      expect(fetched!.isFirstTurn, isFalse);
      expect(fetched.movesCount, 1);
      expect(fetched.movesRecord, isNotEmpty);
      expect(fetched.status, 'active');
    });

    test('applyMove is rejected once the game has finished', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );
      await service.resign(gameId: game.id, uid: 'u1');
      final reversiaGame = ReversiaGame();
      final firstLegal =
          reversiaGame.legalMoves(reversiaGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u1',
        move: firstLegal,
      );

      expect(applied, isFalse);
    });

    test('resign by first makes second the winner', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );

      await service.resign(gameId: game.id, uid: 'u1');

      final fetched = await service.getGame(game.id);
      expect(fetched!.status, 'finished');
      expect(fetched.winnerUid, 'u2');
      expect(fetched.result, 'resignation');
    });

    test('resign by second makes first the winner', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );

      await service.resign(gameId: game.id, uid: 'u2');

      final fetched = await service.getGame(game.id);
      expect(fetched!.winnerUid, 'u1');
    });

    test('resign by a non-participant does nothing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );

      await service.resign(gameId: game.id, uid: 'nobody');

      final fetched = await service.getGame(game.id);
      expect(fetched!.status, 'active');
    });

    test('resign on an already-finished game does not overwrite the result',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );
      await service.resign(gameId: game.id, uid: 'u1');

      await service.resign(gameId: game.id, uid: 'u2');

      final fetched = await service.getGame(game.id);
      expect(fetched!.winnerUid, 'u2'); // unchanged from the first resign
    });

    test('watchGame streams the current snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPvpGameService(firestore);
      final game = await service.createGame(
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
      );

      final emitted = await service.watchGame(game.id).first;

      expect(emitted.id, game.id);
      expect(emitted.firstUid, 'u1');
    });
  });
}
