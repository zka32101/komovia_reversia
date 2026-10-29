import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_challenge_service.dart';

void main() {
  group('ReversiaChallengeService', () {
    test('createChallenge persists a waiting code for the host', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);

      final challenge = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
      );

      expect(challenge.hostUid, 'u1');
      expect(challenge.status, 'waiting');
      expect(challenge.guestUid, isNull);
      expect(challenge.gameId, isNull);
      final fetched = await service.getChallenge(challenge.code);
      expect(fetched, isNotNull);
      expect(fetched!.hostUid, 'u1');
    });

    test('createChallenge retries on a code collision', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);

      // Both calls seed a fresh Random(1), so each call's very first
      // candidate code is identical. The second call's first attempt
      // collides with the first call's already-persisted code, forcing
      // it to retry (advancing the same Random instance) onto a
      // different one.
      final first = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
        random: Random(1),
      );
      final second = await service.createChallenge(
        hostUid: 'u2',
        hostDisplayName: 'Bob',
        random: Random(1),
      );

      expect(second.code, isNot(first.code));
    });

    test('joinChallenge matches a waiting code and records the guest',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);
      final challenge = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
      );

      final joined = await service.joinChallenge(
        code: challenge.code,
        guestUid: 'u2',
        guestDisplayName: 'Bob',
      );

      expect(joined, isNotNull);
      expect(joined!.status, 'matched');
      expect(joined.guestUid, 'u2');
      final fetched = await service.getChallenge(challenge.code);
      expect(fetched!.status, 'matched');
      expect(fetched.guestUid, 'u2');
    });

    test('joinChallenge is case-insensitive on the code', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);
      final challenge = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
      );

      final joined = await service.joinChallenge(
        code: challenge.code.toLowerCase(),
        guestUid: 'u2',
        guestDisplayName: 'Bob',
      );

      expect(joined, isNotNull);
    });

    test('joinChallenge rejects an already-matched code', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);
      final challenge = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
      );
      await service.joinChallenge(
        code: challenge.code,
        guestUid: 'u2',
        guestDisplayName: 'Bob',
      );

      final secondJoin = await service.joinChallenge(
        code: challenge.code,
        guestUid: 'u3',
        guestDisplayName: 'Carol',
      );

      expect(secondJoin, isNull);
    });

    test('joinChallenge rejects the host joining their own code', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);
      final challenge = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
      );

      final joined = await service.joinChallenge(
        code: challenge.code,
        guestUid: 'u1',
        guestDisplayName: 'Alice',
      );

      expect(joined, isNull);
    });

    test('joinChallenge rejects a nonexistent code', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);

      final joined = await service.joinChallenge(
        code: 'NOPE42',
        guestUid: 'u2',
        guestDisplayName: 'Bob',
      );

      expect(joined, isNull);
    });

    test('attachGameToChallenge sets the gameId', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaChallengeService(firestore);
      final challenge = await service.createChallenge(
        hostUid: 'u1',
        hostDisplayName: 'Alice',
      );

      await service.attachGameToChallenge(challenge.code, 'game-1');

      final fetched = await service.getChallenge(challenge.code);
      expect(fetched!.gameId, 'game-1');
    });
  });
}
