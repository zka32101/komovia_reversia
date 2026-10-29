import 'package:cloud_firestore/cloud_firestore.dart';

/// 1人のプレイヤーの、1日分の「今日の1局」挑戦記録。
/// `reversia_puzzle_logs/{uid}/days/{dateKey}`に保存（[dateKey]は
/// `formatReversiaPuzzleDateKey`形式）。1日1ドキュメントに固定する
/// ことで、連続日数(streak)の計算が「その日のドキュメントが存在し、
/// solved==trueか」という直接のdoc getだけで済み、GoEnの
/// `getTsumeGoStreak`のような日ごとのレンジクエリが要らない。
class ReversiaPuzzleLog {
  final String uid;
  final String dateKey;
  final bool solved;
  final int attemptCount;
  final DateTime? solvedAt;

  const ReversiaPuzzleLog({
    required this.uid,
    required this.dateKey,
    required this.solved,
    required this.attemptCount,
    this.solvedAt,
  });

  factory ReversiaPuzzleLog.fromFirestore(
    String uid,
    String dateKey,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReversiaPuzzleLog(
      uid: uid,
      dateKey: dateKey,
      solved: data['solved'] as bool? ?? false,
      attemptCount: data['attemptCount'] as int? ?? 0,
      solvedAt: data['solvedAt'] != null
          ? (data['solvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'solved': solved,
      'attemptCount': attemptCount,
      'solvedAt': solvedAt != null ? Timestamp.fromDate(solvedAt!) : null,
    };
  }
}
