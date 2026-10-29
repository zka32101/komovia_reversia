import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/services/reversia_puzzle_log_service.dart';

void main() {
  group('ReversiaPuzzleLogService', () {
    test('recordAttempt(correct: true) marks the day solved', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);

      await service.recordAttempt(uid: 'u1', dateKey: '2026-01-01', correct: true);

      final log = await service.getLog('u1', '2026-01-01');
      expect(log, isNotNull);
      expect(log!.solved, isTrue);
      expect(log.attemptCount, 1);
      expect(log.solvedAt, isNotNull);
    });

    test('an incorrect attempt does not mark the day solved', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);

      await service.recordAttempt(uid: 'u1', dateKey: '2026-01-01', correct: false);

      final log = await service.getLog('u1', '2026-01-01');
      expect(log!.solved, isFalse);
      expect(log.attemptCount, 1);
      expect(log.solvedAt, isNull);
    });

    test('attemptCount accumulates across multiple attempts on the same day',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);

      await service.recordAttempt(uid: 'u1', dateKey: '2026-01-01', correct: false);
      await service.recordAttempt(uid: 'u1', dateKey: '2026-01-01', correct: true);

      final log = await service.getLog('u1', '2026-01-01');
      expect(log!.attemptCount, 2);
      expect(log.solved, isTrue);
    });

    test('a day already solved cannot be un-solved by a later incorrect attempt',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);

      await service.recordAttempt(uid: 'u1', dateKey: '2026-01-01', correct: true);
      await service.recordAttempt(uid: 'u1', dateKey: '2026-01-01', correct: false);

      final log = await service.getLog('u1', '2026-01-01');
      expect(log!.solved, isTrue);
    });

    test('getLog returns null for a day never attempted', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);

      expect(await service.getLog('u1', '2026-01-01'), isNull);
    });

    test('getStreak counts consecutive solved days ending today', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);
      final today = DateTime.now();
      for (var i = 0; i < 3; i++) {
        final dateKey = formatReversiaPuzzleDateKey(
          today.subtract(Duration(days: i)),
        );
        await service.recordAttempt(uid: 'u1', dateKey: dateKey, correct: true);
      }

      expect(await service.getStreak('u1'), 3);
    });

    test(
        'getStreak does not reset to 0 just because today has not been attempted yet',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);
      final today = DateTime.now();
      for (var i = 1; i <= 3; i++) {
        final dateKey = formatReversiaPuzzleDateKey(
          today.subtract(Duration(days: i)),
        );
        await service.recordAttempt(uid: 'u1', dateKey: dateKey, correct: true);
      }
      // today (i == 0) is never recorded.

      expect(await service.getStreak('u1'), 3);
    });

    test('getStreak stops at the first gap before today', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);
      final today = DateTime.now();
      await service.recordAttempt(
        uid: 'u1',
        dateKey: formatReversiaPuzzleDateKey(today),
        correct: true,
      );
      await service.recordAttempt(
        uid: 'u1',
        dateKey: formatReversiaPuzzleDateKey(today.subtract(const Duration(days: 1))),
        correct: true,
      );
      // day -2 skipped entirely (gap).
      await service.recordAttempt(
        uid: 'u1',
        dateKey: formatReversiaPuzzleDateKey(today.subtract(const Duration(days: 3))),
        correct: true,
      );

      expect(await service.getStreak('u1'), 2);
    });

    test('getStreak is 0 for a user who has never solved a puzzle', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);

      expect(await service.getStreak('u1'), 0);
    });

    test('an unsolved attempt today does not break an existing streak', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReversiaPuzzleLogService(firestore);
      final today = DateTime.now();
      await service.recordAttempt(
        uid: 'u1',
        dateKey: formatReversiaPuzzleDateKey(today.subtract(const Duration(days: 1))),
        correct: true,
      );
      await service.recordAttempt(
        uid: 'u1',
        dateKey: formatReversiaPuzzleDateKey(today),
        correct: false,
      );

      expect(await service.getStreak('u1'), 1);
    });
  });
}
