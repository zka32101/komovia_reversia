import 'package:cloud_firestore/cloud_firestore.dart';

/// マッチメイキング待機列のエントリ。komovia_shogiの
/// `ShogiMatchmakingQueueEntry`と同じ役割（reversiaも一盤種のみなので
/// `boardSize`は無い）。
class ReversiaMatchmakingQueueEntry {
  final String uid;
  final String displayName;
  final int rating;
  final DateTime queuedAt;
  final String status; // 'waiting', 'matched', 'cancelled'

  ReversiaMatchmakingQueueEntry({
    required this.uid,
    required this.displayName,
    required this.rating,
    required this.queuedAt,
    required this.status,
  });

  factory ReversiaMatchmakingQueueEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReversiaMatchmakingQueueEntry(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Player',
      rating: data['rating'] as int? ?? 1200,
      queuedAt: data['queuedAt'] != null
          ? (data['queuedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'waiting',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'rating': rating,
      'queuedAt': Timestamp.fromDate(queuedAt),
      'status': status,
    };
  }
}

/// 成立したマッチ。komovia_shogiの`ShogiMatchResult`と同じ役割。
class ReversiaMatchResult {
  final String id;
  final String player1Uid;
  final String player1DisplayName;
  final int player1Rating;
  final String player2Uid;
  final String player2DisplayName;
  final int player2Rating;
  final int ratingDiff;
  final DateTime createdAt;
  final String? gameId;

  ReversiaMatchResult({
    required this.id,
    required this.player1Uid,
    required this.player1DisplayName,
    required this.player1Rating,
    required this.player2Uid,
    required this.player2DisplayName,
    required this.player2Rating,
    required this.ratingDiff,
    required this.createdAt,
    this.gameId,
  });

  factory ReversiaMatchResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReversiaMatchResult(
      id: doc.id,
      player1Uid: data['player1Uid'] as String? ?? '',
      player1DisplayName: data['player1DisplayName'] as String? ?? 'Player',
      player1Rating: data['player1Rating'] as int? ?? 1200,
      player2Uid: data['player2Uid'] as String? ?? '',
      player2DisplayName: data['player2DisplayName'] as String? ?? 'Player',
      player2Rating: data['player2Rating'] as int? ?? 1200,
      ratingDiff: data['ratingDiff'] as int? ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      gameId: data['gameId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'player1Uid': player1Uid,
      'player1DisplayName': player1DisplayName,
      'player1Rating': player1Rating,
      'player2Uid': player2Uid,
      'player2DisplayName': player2DisplayName,
      'player2Rating': player2Rating,
      'ratingDiff': ratingDiff,
      'createdAt': Timestamp.fromDate(createdAt),
      'gameId': gameId,
    };
  }
}
