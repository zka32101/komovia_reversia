import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reversia_game_stats.dart';
import '../services/reversia_game_stats_service.dart';
import 'auth_provider.dart';

final reversiaGameStatsServiceProvider = Provider<ReversiaGameStatsService>(
  (ref) => ReversiaGameStatsService(),
);

/// 自分自身のAI対局の勝敗・連勝記録。未サインインならnull。
final myReversiaGameStatsProvider = StreamProvider<ReversiaGameStats?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(reversiaGameStatsServiceProvider).watchStats(uid);
});
