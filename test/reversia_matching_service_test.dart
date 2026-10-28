import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/models/reversia_matching.dart';
import 'package:komovia_reversia/services/reversia_matching_service.dart';

void main() {
  group('ReversiaMatchingService', () {
    test('findMatch returns null when the queue is empty', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);

      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      expect(match, isNull);
    });

    test('findMatch pairs two waiting players within the rating threshold',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);
      await service.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1250);

      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      expect(match, isNotNull);
      expect(match!.player1Uid, 'u1');
      expect(match.player2Uid, 'u2');
      expect(match.ratingDiff, 50);

      final selfDoc =
          await firestore.collection('reversia_matchmaking_queue').doc('u1').get();
      final candidateDoc =
          await firestore.collection('reversia_matchmaking_queue').doc('u2').get();
      expect(selfDoc.data()!['status'], 'matched');
      expect(candidateDoc.data()!['status'], 'matched');
    });

    test('findMatch returns null when the caller never joined the queue',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);

      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      expect(match, isNull);
    });

    test('findMatch skips candidates outside the rating threshold', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);
      await service.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1500);

      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      expect(match, isNull);
    });

    test('findMatch never matches the caller with themselves', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);

      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      expect(match, isNull);
    });

    test('findMatch skips a candidate already matched by someone else',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);
      await service.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);
      // Simulate another transaction having already claimed u2.
      await firestore
          .collection('reversia_matchmaking_queue')
          .doc('u2')
          .update({'status': 'matched'});

      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      expect(match, isNull);
    });

    test('leaveQueue removes the queue entry', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);

      await service.leaveQueue('u1');

      final doc =
          await firestore.collection('reversia_matchmaking_queue').doc('u1').get();
      expect(doc.exists, isFalse);
    });

    test('attachGameToMatch sets gameId on the match result', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);
      await service.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);
      final match = await service.findMatch(
        uid: 'u1',
        displayName: 'Alice',
        rating: 1200,
      );

      await service.attachGameToMatch(match!.id, 'game-123');

      final doc =
          await firestore.collection('reversia_match_results').doc(match.id).get();
      expect(doc.data()!['gameId'], 'game-123');
    });

    test('getMatchHistory returns matches for either player', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaMatchingService(firestore);
      await service.joinQueue(uid: 'u1', displayName: 'Alice', rating: 1200);
      await service.joinQueue(uid: 'u2', displayName: 'Bob', rating: 1200);
      await service.findMatch(uid: 'u1', displayName: 'Alice', rating: 1200);

      final historyAsP1 = await service.getMatchHistory('u1');
      final historyAsP2 = await service.getMatchHistory('u2');

      expect(historyAsP1, hasLength(1));
      expect(historyAsP2, hasLength(1));
      expect(historyAsP1.single.id, historyAsP2.single.id);
    });
  });

  group('ReversiaMatchmakingQueueEntry.fromFirestore', () {
    test('falls back to defaults for a document missing fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reversia_matchmaking_queue').doc('u1').set({});
      final doc =
          await firestore.collection('reversia_matchmaking_queue').doc('u1').get();

      final entry = ReversiaMatchmakingQueueEntry.fromFirestore(doc);

      expect(entry.uid, 'u1');
      expect(entry.rating, 1200);
      expect(entry.status, 'waiting');
    });
  });
}
