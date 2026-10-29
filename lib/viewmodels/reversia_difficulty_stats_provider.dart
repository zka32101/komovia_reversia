import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reversia_difficulty_stats.dart';
import '../services/reversia_difficulty_stats_service.dart';
import 'auth_provider.dart';

final reversiaDifficultyStatsServiceProvider = Provider<ReversiaDifficultyStatsService>(
  (ref) => ReversiaDifficultyStatsService(FirebaseFirestore.instance),
);

/// 自分自身のAI難易度別対局数・勝数。未サインインならnull。
final myReversiaDifficultyStatsProvider = StreamProvider<ReversiaDifficultyStats?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(reversiaDifficultyStatsServiceProvider).watchStats(uid);
});
