import 'reversia_pvp_game.dart';

/// 現在進行中(active)のPvP対局を持つフレンド1人分 - 「ライブ観戦フレンド」
/// 機能（komovia_goの`FriendActivity`に相当）。`ReversiaPvpGame`自体は
/// 既存の`reversia_pvp_games`コレクションのドキュメントを参照するだけで、
/// 専用のSpectatorSessionは作らない - `ReversiaPvpGameScreen`は非対局者
/// (uidが対局者でない)に対し既に読み取り専用の観戦表示（「観戦中」）を
/// 提供しているため、観戦用の別画面・別Firestoreスキーマは不要
/// （firestore.rulesの`reversia_pvp_games`読み取り権限をフレンドにも
/// 広げるだけで実現できる）。
class LiveFriendActivity {
  const LiveFriendActivity({
    required this.friendUid,
    required this.friendDisplayName,
    required this.game,
  });

  final String friendUid;
  final String friendDisplayName;
  final ReversiaPvpGame game;
}
