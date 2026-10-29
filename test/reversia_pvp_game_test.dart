import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/models/reversia_pvp_game.dart';

void main() {
  group('ReversiaPvpGame', () {
    test('playerColorOf identifies first/second/neither', () {
      final game = ReversiaPvpGame(
        id: 'g1',
        firstUid: 'first-uid',
        firstDisplayName: 'Alice',
        secondUid: 'second-uid',
        secondDisplayName: 'Bob',
        isFirstTurn: true,
        movesCount: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(game.playerColorOf('first-uid'), 1);
      expect(game.playerColorOf('second-uid'), 2);
      expect(game.playerColorOf('nobody'), 0);
    });

    test('isTurnOf reflects isFirstTurn for each player', () {
      final game = ReversiaPvpGame(
        id: 'g1',
        firstUid: 'first-uid',
        firstDisplayName: 'Alice',
        secondUid: 'second-uid',
        secondDisplayName: 'Bob',
        isFirstTurn: true,
        movesCount: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(game.isTurnOf('first-uid'), isTrue);
      expect(game.isTurnOf('second-uid'), isFalse);
      expect(game.isTurnOf('nobody'), isFalse);
    });

    test('isActive/isFinished reflect status', () {
      final base = ReversiaPvpGame(
        id: 'g1',
        firstUid: 'f',
        firstDisplayName: 'Alice',
        secondUid: 's',
        secondDisplayName: 'Bob',
        isFirstTurn: true,
        movesCount: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );
      expect(base.isActive, isTrue);
      expect(base.isFinished, isFalse);

      final finished = ReversiaPvpGame(
        id: 'g1',
        firstUid: 'f',
        firstDisplayName: 'Alice',
        secondUid: 's',
        secondDisplayName: 'Bob',
        isFirstTurn: true,
        movesCount: 10,
        status: 'finished',
        winnerUid: 'f',
        result: 'resignation',
        createdAt: DateTime.now(),
      );
      expect(finished.isActive, isFalse);
      expect(finished.isFinished, isTrue);
    });
  });

  group('canClaimAbandonmentForfeit', () {
    ReversiaPvpGame gameWith({
      required DateTime? updatedAt,
      required DateTime createdAt,
      String status = 'active',
      bool isFirstTurn = false,
    }) {
      return ReversiaPvpGame(
        id: 'g1',
        firstUid: 'first-uid',
        firstDisplayName: 'Alice',
        secondUid: 'second-uid',
        secondDisplayName: 'Bob',
        isFirstTurn: isFirstTurn,
        movesCount: 1,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }

    test('true for the waiting player once the threshold has elapsed', () {
      final game = gameWith(
        createdAt: DateTime.now().subtract(const Duration(hours: 50)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 49)),
        isFirstTurn: false, // it's second-uid's turn; first-uid is waiting
      );

      expect(
        game.canClaimAbandonmentForfeit('first-uid', threshold: const Duration(hours: 48)),
        isTrue,
      );
    });

    test('false before the threshold has elapsed', () {
      final game = gameWith(
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        isFirstTurn: false,
      );

      expect(
        game.canClaimAbandonmentForfeit('first-uid', threshold: const Duration(hours: 48)),
        isFalse,
      );
    });

    test('false for the player whose own turn it currently is', () {
      final game = gameWith(
        createdAt: DateTime.now().subtract(const Duration(hours: 50)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 49)),
        isFirstTurn: false, // second-uid's turn
      );

      expect(
        game.canClaimAbandonmentForfeit('second-uid', threshold: const Duration(hours: 48)),
        isFalse,
      );
    });

    test('false for a non-participant', () {
      final game = gameWith(
        createdAt: DateTime.now().subtract(const Duration(hours: 50)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 49)),
      );

      expect(
        game.canClaimAbandonmentForfeit('nobody', threshold: const Duration(hours: 48)),
        isFalse,
      );
    });

    test('false once the game is already finished', () {
      final game = gameWith(
        createdAt: DateTime.now().subtract(const Duration(hours: 50)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 49)),
        status: 'finished',
      );

      expect(
        game.canClaimAbandonmentForfeit('first-uid', threshold: const Duration(hours: 48)),
        isFalse,
      );
    });

    test('falls back to createdAt when updatedAt was never set', () {
      final game = gameWith(
        createdAt: DateTime.now().subtract(const Duration(hours: 50)),
        updatedAt: null,
        isFirstTurn: false,
      );

      expect(
        game.canClaimAbandonmentForfeit('first-uid', threshold: const Duration(hours: 48)),
        isTrue,
      );
    });
  });

  group('ReversiaPvpGame.fromFirestore / toFirestore', () {
    test('round-trips through Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final ref = firestore.collection('reversia_pvp_games').doc();
      final game = ReversiaPvpGame(
        id: ref.id,
        firstUid: 'u1',
        firstDisplayName: 'Alice',
        secondUid: 'u2',
        secondDisplayName: 'Bob',
        movesRecord: 'reversia\nongoing,,\n',
        isFirstTurn: false,
        movesCount: 3,
        status: 'active',
        matchId: 'm1',
        createdAt: DateTime(2026, 1, 1),
      );

      await ref.set(game.toFirestore());
      final doc = await ref.get();
      final fetched = ReversiaPvpGame.fromFirestore(
        doc,
      );

      expect(fetched.id, ref.id);
      expect(fetched.firstUid, 'u1');
      expect(fetched.secondUid, 'u2');
      expect(fetched.movesRecord, game.movesRecord);
      expect(fetched.isFirstTurn, isFalse);
      expect(fetched.movesCount, 3);
      expect(fetched.matchId, 'm1');
    });

    test('falls back to defaults for a document missing fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reversia_pvp_games').doc('g1').set({});
      final doc =
          await firestore.collection('reversia_pvp_games').doc('g1').get();

      final game = ReversiaPvpGame.fromFirestore(
        doc,
      );

      expect(game.id, 'g1');
      expect(game.movesRecord, '');
      expect(game.isFirstTurn, isTrue);
      expect(game.movesCount, 0);
      expect(game.status, 'active');
      expect(game.winnerUid, isNull);
      expect(game.result, isNull);
      expect(game.matchId, isNull);
    });
  });
}
