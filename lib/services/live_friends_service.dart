import '../models/live_friend_activity.dart';
import 'friend_service.dart';
import 'reversia_pvp_game_service.dart';

/// 「ライブ観戦フレンド」 - いま観戦可能な（進行中のPvP対局を持つ）
/// フレンドの一覧を求める。komovia_goの`FriendActivityService`と同じ
/// 役割だが、専用コレクションは持たず、既存の`FriendService.friendsStream`
/// + `ReversiaPvpGameService.getUserActiveGames`を組み合わせるだけで
/// 実現する（フレンド数が多いアプリでは重いN+1クエリだが、このアプリの
/// 規模では許容範囲）。
class LiveFriendsService {
  LiveFriendsService({
    required FriendService friendService,
    required ReversiaPvpGameService pvpGameService,
  })  : _friendService = friendService,
        _pvpGameService = pvpGameService;

  final FriendService _friendService;
  final ReversiaPvpGameService _pvpGameService;

  Future<List<LiveFriendActivity>> getLiveFriends(String uid) async {
    final friends = await _friendService.friendsStream(uid).first;
    final activities = <LiveFriendActivity>[];
    for (final friend in friends) {
      final games = await _pvpGameService.getUserActiveGames(friend.friendUid);
      for (final game in games) {
        activities.add(LiveFriendActivity(
          friendUid: friend.friendUid,
          friendDisplayName: friend.displayName,
          game: game,
        ));
      }
    }
    return activities;
  }
}
