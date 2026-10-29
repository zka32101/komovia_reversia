import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'reversia_pvp_game_screen.dart';

/// ライブ観戦フレンド画面 - いま対局中のフレンドを一覧表示し、タップで
/// `ReversiaPvpGameScreen`を観戦者として開く（komovia_goの
/// `live_friends_screen.dart`と同じ役割）。盤面の読み取り自体は
/// `ReversiaPvpGameScreen`が非対局者向けに既に持っている観戦表示を
/// そのまま使う。
class LiveFriendsScreen extends ConsumerWidget {
  const LiveFriendsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveFriends = ref.watch(liveFriendsProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('ライブ観戦フレンド')),
      body: liveFriends.when(
        data: (activities) => activities.isEmpty
            ? const Center(child: Text('いま対局中のフレンドはいません'))
            : ListView(
                children: activities.map((a) {
                  return ListTile(
                    leading: const Icon(Icons.live_tv),
                    title: Text(a.friendDisplayName),
                    subtitle: const Text('対局中'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReversiaPvpGameScreen(gameId: a.game.id),
                      ),
                    ),
                  );
                }).toList(),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('読み込みに失敗しました')),
      ),
    );
  }
}
