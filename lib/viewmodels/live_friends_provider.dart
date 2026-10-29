import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_friend_activity.dart';
import '../services/live_friends_service.dart';
import 'friend_provider.dart';
import 'reversia_pvp_game_provider.dart';

final liveFriendsServiceProvider = Provider<LiveFriendsService>(
  (ref) => LiveFriendsService(
    friendService: ref.watch(friendServiceProvider),
    pvpGameService: ref.watch(reversiaPvpGameServiceProvider),
  ),
);

final liveFriendsProvider =
    FutureProvider.family<List<LiveFriendActivity>, String>(
  (ref, uid) => ref.watch(liveFriendsServiceProvider).getLiveFriends(uid),
);
