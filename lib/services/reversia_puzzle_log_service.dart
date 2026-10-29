import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/reversia_puzzle_log.dart';
import '../src/reversia_puzzle.dart';

/// 「今日の1局」の挑戦記録・連続日数(streak)サービス。
class ReversiaPuzzleLogService {
  ReversiaPuzzleLogService(this._firestore);

  final FirebaseFirestore _firestore;

  /// 連続日数を計算する際にさかのぼる最大日数（GoEnの`getTsumeGoStreak`
  /// と同じ上限。実際には最初に途切れた日で走査は止まるため、この上限
  /// に達するのは1年間毎日解き続けた場合のみ）。
  static const int maxStreakLookbackDays = 365;

  DocumentReference<Map<String, dynamic>> _dayDoc(String uid, String dateKey) =>
      _firestore
          .collection('reversia_puzzle_logs')
          .doc(uid)
          .collection('days')
          .doc(dateKey);

  /// その日の挑戦を記録する。トランザクション内で読み取り・更新する
  /// ことで、同じ日に複数回挑戦しても`attemptCount`が正しく加算され、
  /// 一度`solved`になった日が後から`false`に戻ることはない。
  Future<void> recordAttempt({
    required String uid,
    required String dateKey,
    required bool correct,
  }) {
    final ref = _dayDoc(uid, dateKey);
    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = ReversiaPuzzleLog.fromFirestore(uid, dateKey, snapshot);
      final updated = ReversiaPuzzleLog(
        uid: uid,
        dateKey: dateKey,
        solved: current.solved || correct,
        attemptCount: current.attemptCount + 1,
        solvedAt: current.solvedAt ?? (correct ? DateTime.now() : null),
      );
      transaction.set(ref, updated.toFirestore());
    });
  }

  Future<ReversiaPuzzleLog?> getLog(String uid, String dateKey) async {
    final doc = await _dayDoc(uid, dateKey).get();
    if (!doc.exists) return null;
    return ReversiaPuzzleLog.fromFirestore(uid, dateKey, doc);
  }

  /// [uid]の現在の連続解答日数。komovia_coreの`computeDailyStreak`
  /// （komovia_goの`getTsumeGoStreak`と全く同じ日付ウォークアルゴリズム
  /// を共通化したもの）を使う - `todayIsLenient`の既定値`true`により、
  /// 今日まだ解いていなくても前日までの連続は失われない（今日という日
  /// がまだ「連続が途切れた日」として確定していないため）。
  Future<int> getStreak(String uid) {
    return computeDailyStreak(
      (daysAgo) async {
        final date = DateTime.now().subtract(Duration(days: daysAgo));
        final log = await getLog(uid, formatReversiaPuzzleDateKey(date));
        return log != null && log.solved;
      },
      lookbackDays: maxStreakLookbackDays,
    );
  }
}
