import 'package:cloud_firestore/cloud_firestore.dart';

import 'leaderboard_service.dart';

/// 実績（アチーブメント）CRUD - komovia_chessの`achievement_service.dart`
/// と同じ役割だが、進捗の元データを`users/{uid}`の生フィールドではなく
/// `LeaderboardService`（`LeaderboardEntry.wins`/`puzzlesSolved`）から
/// 読む設計にしている - reversiaは勝敗・パズル解答数をすでにそちらで
/// 一元管理しているため（二重管理を避ける）。
///
/// 実績の定義（[AchievementDefinition]）はkomovia_chessと同じく、
/// 管理者が入力する実データがまだ無いためハードコードした
/// bootstrap定義のみを使う - `achievements/definitions`のような
/// curated collectionはこのリポジトリにseedスクリプトが無く作れない
/// ため、意図的に用意していない。
class AchievementService {
  AchievementService({FirebaseFirestore? firestore, LeaderboardService? leaderboard})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _leaderboard = leaderboard ?? LeaderboardService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final LeaderboardService _leaderboard;

  static final List<AchievementDefinition> definitions = [
    AchievementDefinition(
      id: 'first_win',
      name: '初勝利',
      description: '最初の対局に勝つ',
      icon: '🏆',
      targetValue: 1,
    ),
    AchievementDefinition(
      id: 'five_wins',
      name: '上昇気流',
      description: '5勝する',
      icon: '⭐',
      targetValue: 5,
    ),
    AchievementDefinition(
      id: 'ten_wins',
      name: '常勝への道',
      description: '10勝する',
      icon: '🔥',
      targetValue: 10,
    ),
    AchievementDefinition(
      id: 'puzzle_master',
      name: 'パズルマスター',
      description: '「今日の1局」を20回解く',
      icon: '🧩',
      targetValue: 20,
    ),
  ];

  CollectionReference<Map<String, Object?>> _unlockedOf(String uid) =>
      _firestore.collection('achievements').doc(uid).collection('unlocked');

  /// [achievementId]が[uid]ですでに解除されているかどうか。
  Future<bool> isUnlocked(String uid, String achievementId) async {
    final doc = await _unlockedOf(uid).doc(achievementId).get();
    return doc.exists;
  }

  Stream<Set<String>> unlockedIdsStream(String uid) {
    return _unlockedOf(uid)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  int _currentValueFor(String achievementId, int wins, int puzzlesSolved) {
    switch (achievementId) {
      case 'first_win':
        return wins > 0 ? 1 : 0;
      case 'five_wins':
      case 'ten_wins':
        return wins;
      case 'puzzle_master':
        return puzzlesSolved;
      default:
        return 0;
    }
  }

  /// 全ての実績定義について[uid]の現在の進捗を返す。
  Future<List<AchievementProgress>> getAllProgress(String uid) async {
    final entry = await _leaderboard.getEntry(uid);
    final wins = entry?.wins ?? 0;
    final puzzlesSolved = entry?.puzzlesSolved ?? 0;
    final unlockedIds = (await _unlockedOf(uid).get()).docs.map((d) => d.id).toSet();

    return definitions.map((def) {
      final isUnlocked = unlockedIds.contains(def.id);
      return AchievementProgress(
        definition: def,
        isUnlocked: isUnlocked,
        currentValue: isUnlocked
            ? def.targetValue
            : _currentValueFor(def.id, wins, puzzlesSolved),
      );
    }).toList();
  }

  /// [achievementId]を解除する。トランザクション内で既存を再確認する
  /// ことで、ほぼ同時に複数のトリガー（対局勝利とパズル解答など）から
  /// 呼ばれても二重に解除・二重にカウントされない。解除時に
  /// `LeaderboardEntry.achievementsUnlocked`を+1する（best-effort）。
  Future<void> unlockAchievement(String uid, String achievementId) async {
    final ref = _unlockedOf(uid).doc(achievementId);
    final didUnlock = await _firestore.runTransaction<bool>((transaction) async {
      final doc = await transaction.get(ref);
      if (doc.exists) return false;
      transaction.set(ref, {
        'achievementId': achievementId,
        'unlockedAt': DateTime.now().toIso8601String(),
      });
      return true;
    });

    if (didUnlock) {
      try {
        final entry = await _leaderboard.getEntry(uid);
        await _leaderboard.incrementStats(
          uid: uid,
          displayName: entry?.displayName ?? 'Player',
          achievementsDelta: 1,
        );
      } catch (_) {
        // best-effort: 実績の解除自体は既に成功している
      }
    }
  }

  /// 全ての実績定義について進捗を確認し、目標に到達したものを解除する。
  /// 対局勝利・パズル解答などの直後にbest-effortで呼ばれる想定
  /// （失敗してもそれらの処理自体はブロックしない）。
  Future<void> checkAndUnlockAchievements(String uid) async {
    final progress = await getAllProgress(uid);
    for (final p in progress) {
      if (!p.isUnlocked && p.currentValue >= p.definition.targetValue) {
        await unlockAchievement(uid, p.definition.id);
      }
    }
  }
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.targetValue,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int targetValue;
}

class AchievementProgress {
  const AchievementProgress({
    required this.definition,
    required this.isUnlocked,
    required this.currentValue,
  });

  final AchievementDefinition definition;
  final bool isUnlocked;
  final int currentValue;

  double get progressPercent =>
      definition.targetValue == 0 ? 0 : (currentValue / definition.targetValue).clamp(0.0, 1.0);
}
