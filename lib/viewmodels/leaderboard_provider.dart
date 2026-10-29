import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/leaderboard_service.dart';
import 'auth_provider.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>(
  (ref) => LeaderboardService(),
);

final topLeaderboardEntriesProvider = StreamProvider<List<LeaderboardEntry>>(
  (ref) => ref.watch(leaderboardServiceProvider).topEntriesStream(),
);

/// 自分自身のランキングエントリー。トップ50に入っていなくても取得できる
/// よう、`topLeaderboardEntriesProvider`とは別に単独取得する。未サイン
/// イン、またはまだ一度も対局を終えていない場合はnull。
final myLeaderboardEntryProvider = FutureProvider<LeaderboardEntry?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Future.value(null);
  return ref.watch(leaderboardServiceProvider).getEntry(uid);
});
