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
