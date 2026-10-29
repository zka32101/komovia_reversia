import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/achievement_service.dart';
import 'package:komovia_reversia/services/leaderboard_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LeaderboardService leaderboard;
  late AchievementService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    leaderboard = LeaderboardService(firestore: firestore);
    service = AchievementService(firestore: firestore, leaderboard: leaderboard);
  });

  test('getAllProgress with no history shows every achievement locked at 0 progress', () async {
    final progress = await service.getAllProgress('u1');

    expect(progress, hasLength(AchievementService.definitions.length));
    expect(progress.every((p) => !p.isUnlocked), isTrue);
    expect(progress.every((p) => p.currentValue == 0), isTrue);
  });

  test('getAllProgress reflects wins and puzzlesSolved from the leaderboard entry', () async {
    await leaderboard.incrementStats(uid: 'u1', displayName: 'Alice', winsDelta: 3, gamesDelta: 3);
    await leaderboard.incrementStats(uid: 'u1', displayName: 'Alice', puzzlesDelta: 7);

    final progress = await service.getAllProgress('u1');
    final firstWin = progress.firstWhere((p) => p.definition.id == 'first_win');
    final fiveWins = progress.firstWhere((p) => p.definition.id == 'five_wins');
    final puzzleMaster = progress.firstWhere((p) => p.definition.id == 'puzzle_master');

    expect(firstWin.currentValue, 1);
    expect(fiveWins.currentValue, 3);
    expect(puzzleMaster.currentValue, 7);
  });

  test('unlockAchievement persists it and increments achievementsUnlocked once', () async {
    await leaderboard.incrementStats(uid: 'u1', displayName: 'Alice', winsDelta: 1, gamesDelta: 1);

    await service.unlockAchievement('u1', 'first_win');
    await service.unlockAchievement('u1', 'first_win');

    expect(await service.isUnlocked('u1', 'first_win'), isTrue);
    final entry = await leaderboard.getEntry('u1');
    expect(entry!.achievementsUnlocked, 1);
  });

  test('checkAndUnlockAchievements unlocks every achievement whose target is met', () async {
    await leaderboard.incrementStats(uid: 'u1', displayName: 'Alice', winsDelta: 5, gamesDelta: 5);

    await service.checkAndUnlockAchievements('u1');

    expect(await service.isUnlocked('u1', 'first_win'), isTrue);
    expect(await service.isUnlocked('u1', 'five_wins'), isTrue);
    expect(await service.isUnlocked('u1', 'ten_wins'), isFalse);
  });

  test('checkAndUnlockAchievements never re-unlocks an already-unlocked achievement', () async {
    await leaderboard.incrementStats(uid: 'u1', displayName: 'Alice', winsDelta: 1, gamesDelta: 1);
    await service.checkAndUnlockAchievements('u1');
    final entryAfterFirst = await leaderboard.getEntry('u1');

    await service.checkAndUnlockAchievements('u1');
    final entryAfterSecond = await leaderboard.getEntry('u1');

    expect(entryAfterFirst!.achievementsUnlocked, entryAfterSecond!.achievementsUnlocked);
  });

  test('unlockedIdsStream reflects currently-unlocked achievements', () async {
    await leaderboard.incrementStats(uid: 'u1', displayName: 'Alice', winsDelta: 1, gamesDelta: 1);
    await service.unlockAchievement('u1', 'first_win');

    final ids = await service.unlockedIdsStream('u1').first;
    expect(ids, {'first_win'});
  });
}
