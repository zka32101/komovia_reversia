import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/reversia_puzzle_log_service.dart';
import 'package:komovia_reversia/services/reversia_weekly_progress_service.dart';
import 'package:komovia_reversia/viewmodels/reversia_puzzle_log_provider.dart';
import 'package:komovia_reversia/viewmodels/reversia_weekly_progress_provider.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [
        reversiaPuzzleLogServiceProvider.overrideWithValue(
          ReversiaPuzzleLogService(firestore),
        ),
        reversiaWeeklyProgressServiceProvider.overrideWithValue(
          ReversiaWeeklyProgressService(firestore),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('solving the daily puzzle for the first time counts toward the weekly goal', () async {
    final record = container.read(recordReversiaPuzzleAttemptProvider);
    await record(uid: 'u1', dateKey: '2026-10-28', correct: true);

    final weeklyService = container.read(reversiaWeeklyProgressServiceProvider);
    final progress = await weeklyService.getProgress('u1');
    expect(progress.puzzlesSolved, 1);
  });

  test('re-solving the same already-solved day does not double-count', () async {
    final record = container.read(recordReversiaPuzzleAttemptProvider);
    await record(uid: 'u1', dateKey: '2026-10-28', correct: true);
    await record(uid: 'u1', dateKey: '2026-10-28', correct: true);

    final weeklyService = container.read(reversiaWeeklyProgressServiceProvider);
    final progress = await weeklyService.getProgress('u1');
    expect(progress.puzzlesSolved, 1);
  });

  test('an incorrect attempt does not count toward the weekly goal', () async {
    final record = container.read(recordReversiaPuzzleAttemptProvider);
    await record(uid: 'u1', dateKey: '2026-10-28', correct: false);

    final weeklyService = container.read(reversiaWeeklyProgressServiceProvider);
    final progress = await weeklyService.getProgress('u1');
    expect(progress.puzzlesSolved, 0);
  });
}
