import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_weekly_progress_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReversiaWeeklyProgressService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ReversiaWeeklyProgressService(firestore);
  });

  test('getProgress returns zeroed progress when nothing was ever recorded', () async {
    final progress = await service.getProgress('u1');
    expect(progress.gamesPlayed, 0);
    expect(progress.wins, 0);
    expect(progress.puzzlesSolved, 0);
  });

  test('recordGamePlayed increments gamesPlayed, and wins only when won', () async {
    await service.recordGamePlayed(uid: 'u1', won: true);
    await service.recordGamePlayed(uid: 'u1', won: false);

    final progress = await service.getProgress('u1');
    expect(progress.gamesPlayed, 2);
    expect(progress.wins, 1);
  });

  test('recordPuzzleSolved increments puzzlesSolved without touching game counters', () async {
    await service.recordPuzzleSolved(uid: 'u1');
    await service.recordPuzzleSolved(uid: 'u1');

    final progress = await service.getProgress('u1');
    expect(progress.puzzlesSolved, 2);
    expect(progress.gamesPlayed, 0);
  });

  test('progress is tracked independently per uid', () async {
    await service.recordGamePlayed(uid: 'u1', won: true);
    final other = await service.getProgress('u2');
    expect(other.gamesPlayed, 0);
  });

  test('watchProgress streams the initial value, then updates after a write', () async {
    final before = await service.watchProgress('u1').first;
    expect(before.gamesPlayed, 0);

    await service.recordGamePlayed(uid: 'u1', won: true);
    await Future<void>.delayed(Duration.zero);

    final after = await service.watchProgress('u1').first;
    expect(after.gamesPlayed, 1);
  });

  test('a game recorded in a different simulated week lands in a separate document', () async {
    final thisWeek = DateTime(2026, 10, 28);
    final nextWeek = DateTime(2026, 11, 4);

    await service.recordGamePlayed(uid: 'u1', won: true, now: thisWeek);
    final thisWeekProgress = await service.getProgress('u1', now: thisWeek);
    final nextWeekProgress = await service.getProgress('u1', now: nextWeek);

    expect(thisWeekProgress.gamesPlayed, 1);
    expect(nextWeekProgress.gamesPlayed, 0);
  });
}
