import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reversia_matching.dart';
import '../services/reversia_matching_service.dart';

/// komovia_shogiの`shogi_matching_provider.dart`と同じ役割（reversia向け）。
/// `ReversiaMatchingService`の薄いRiverpodラッパー。
final reversiaMatchingServiceProvider = Provider<ReversiaMatchingService>((ref) {
  return ReversiaMatchingService(FirebaseFirestore.instance);
});

final joinReversiaMatchmakingQueueProvider = Provider<
    Future<void> Function(String uid, String displayName, int rating)>((ref) {
  final service = ref.watch(reversiaMatchingServiceProvider);
  return (uid, displayName, rating) {
    return service.joinQueue(uid: uid, displayName: displayName, rating: rating);
  };
});

final findReversiaMatchProvider = Provider<
    Future<ReversiaMatchResult?> Function(
      String uid,
      String displayName,
      int rating,
    )>((ref) {
  final service = ref.watch(reversiaMatchingServiceProvider);
  return (uid, displayName, rating) {
    return service.findMatch(uid: uid, displayName: displayName, rating: rating);
  };
});

final attachReversiaGameToMatchProvider =
    Provider<Future<void> Function(String matchId, String gameId)>((ref) {
  final service = ref.watch(reversiaMatchingServiceProvider);
  return (matchId, gameId) => service.attachGameToMatch(matchId, gameId);
});

final reversiaMatchHistoryProvider =
    FutureProvider.family<List<ReversiaMatchResult>, String>((ref, uid) {
  return ref.watch(reversiaMatchingServiceProvider).getMatchHistory(uid);
});
