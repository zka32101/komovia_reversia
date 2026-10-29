import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'achievements_screen.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'message_threads_screen.dart';
import 'notification_screen.dart';
import 'puzzle_screen.dart';
import 'reversia_matching_screen.dart';
import 'reversia_pvp_games_list_screen.dart';
import 'settings_screen.dart';
import 'tournament_screen.dart';

/// アプリのホーム画面 - komovia_shogiの`HomeScreen`と同じ役割（reversia向
/// け）。これまで`main.dart`の`_RootScreen`はオンボーディング完了後
/// 直接`ReversiaGameScreen`へ進んでいたが、他のKomoviaシリーズと同じく
/// 対局以外の機能（今日の1局・対局相手探し・PvP一覧・ランキング・設定）
/// への入口をまとめた画面をその手前に挟む。`ReversiaGameScreen`自身の
/// AppBarアイコン（通知・マッチング・ヒント・ランキング・パズル）はこの
/// PRでは変更しない - このホーム画面はナビゲーションの入口を増やすだけ。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onPlayReversia});

  final VoidCallback onPlayReversia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Komovia Reversia'),
            if (uid != null && ref.watch(isPremiumProvider)) ...[
              const SizedBox(width: 6),
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
            ],
          ],
        ),
        actions: [
          if (uid != null)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: '通知',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationScreen(uid: uid),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final count = ref.watch(unreadNotificationCountProvider(uid));
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          if (uid != null)
            Builder(
              builder: (context) {
                final count = ref.watch(unreadMessageCountProvider);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mail_outline),
                      tooltip: 'メッセージ',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MessageThreadsScreen(
                            uid: uid,
                            displayName: 'Player ${uid.substring(0, 6)}',
                          ),
                        ),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.red,
                          child: Text(
                            '$count',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HomeTile(
            icon: Icons.play_circle_fill,
            title: 'プレイ',
            subtitle: 'AIと対局する',
            onTap: onPlayReversia,
          ),
          _HomeTile(
            icon: Icons.calendar_today,
            title: '今日の1局',
            subtitle: '毎日更新されるパズルに挑戦',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PuzzleScreen()),
            ),
          ),
          if (uid != null) ...[
            _HomeTile(
              icon: Icons.group,
              title: '対局相手を探す',
              subtitle: 'マッチングまたは招待コードで対局する',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReversiaMatchingScreen(
                    uid: uid,
                    displayName: 'Player ${uid.substring(0, 6)}',
                  ),
                ),
              ),
            ),
            _HomeTile(
              icon: Icons.list_alt,
              title: '対局中のPvP',
              subtitle: '進行中の対局一覧',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReversiaPvpGamesListScreen(uid: uid),
                ),
              ),
            ),
            _HomeTile(
              icon: Icons.people,
              title: 'フレンド',
              subtitle: 'フレンド申請・管理',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendsScreen(
                    uid: uid,
                    displayName: 'Player ${uid.substring(0, 6)}',
                  ),
                ),
              ),
            ),
            _HomeTile(
              icon: Icons.emoji_events,
              title: 'トーナメント',
              subtitle: '参加・ブラケットを見る',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentScreen(
                    uid: uid,
                    displayName: 'Player ${uid.substring(0, 6)}',
                  ),
                ),
              ),
            ),
            _HomeTile(
              icon: Icons.military_tech,
              title: '実績',
              subtitle: 'バッジ・実績の進捗を見る',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AchievementsScreen(uid: uid),
                ),
              ),
            ),
          ],
          _HomeTile(
            icon: Icons.leaderboard,
            title: 'ランキング',
            subtitle: 'レーティング上位プレイヤー',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          _HomeTile(
            icon: Icons.settings,
            title: '設定',
            subtitle: '利用規約・プライバシーポリシーなど',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(uid: uid)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
