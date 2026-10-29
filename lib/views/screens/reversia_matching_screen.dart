import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reversia_matching.dart';
import '../../viewmodels/index.dart';
import 'reversia_challenge_screen.dart';
import 'reversia_pvp_game_screen.dart';
import 'reversia_pvp_games_list_screen.dart';

/// 実力マッチングEngine画面。komovia_shogiの`ShogiMatchingScreen`と同じ
/// 役割だが、reversiaにはまだレーティング/リーダーボード機能が無いため
/// （社交機能はこのPRの前段のFirebase基盤PRのみ）、全員固定のデフォルト
/// レート(1200)でマッチングする - 実際のレート機能が追加されたら、この
/// 画面はそれを読みに行くよう差し替える想定。
class ReversiaMatchingScreen extends ConsumerStatefulWidget {
  const ReversiaMatchingScreen({
    super.key,
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;

  static const int defaultRating = 1200;

  @override
  ConsumerState<ReversiaMatchingScreen> createState() =>
      _ReversiaMatchingScreenState();
}

class _ReversiaMatchingScreenState extends ConsumerState<ReversiaMatchingScreen> {
  bool _isSearching = false;
  bool _isStartingGame = false;
  ReversiaMatchResult? _foundMatch;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('対局相手を探す'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: '対局中のPvP',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReversiaPvpGamesListScreen(uid: widget.uid),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('対局相手を探してマッチングします。'),
            const SizedBox(height: 20),
            if (_foundMatch != null) _buildMatchFoundCard(_foundMatch!),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSearching ? null : _findMatch,
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('対局相手を探す'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReversiaChallengeScreen(
                      uid: widget.uid,
                      displayName: widget.displayName,
                    ),
                  ),
                ),
                child: const Text('特定の相手と対戦する（招待コード）'),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '対局履歴',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMatchHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchFoundCard(ReversiaMatchResult match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake),
              const SizedBox(width: 8),
              const Text('対局相手が見つかりました', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${match.player1DisplayName} vs ${match.player2DisplayName}'),
          if (match.gameId == null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isStartingGame ? null : () => _startGame(match),
                child: _isStartingGame
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('対局を開始する'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchHistory() {
    final historyAsync = ref.watch(reversiaMatchHistoryProvider(widget.uid));
    return historyAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const Text('対局履歴はまだありません');
        }
        return Column(
          children: matches.map((match) {
            final isPlayer1 = match.player1Uid == widget.uid;
            final opponentName =
                isPlayer1 ? match.player2DisplayName : match.player1DisplayName;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(opponentName),
                trailing: match.gameId != null
                    ? const Icon(Icons.arrow_forward_ios, size: 16)
                    : null,
                onTap: match.gameId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReversiaPvpGameScreen(gameId: match.gameId!),
                          ),
                        ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text(
        'エラー: $err',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Future<void> _findMatch() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      await ref.read(joinReversiaMatchmakingQueueProvider)(
        widget.uid,
        widget.displayName,
        ReversiaMatchingScreen.defaultRating,
      );
      final match = await ref.read(findReversiaMatchProvider)(
        widget.uid,
        widget.displayName,
        ReversiaMatchingScreen.defaultRating,
      );

      if (!mounted) return;
      setState(() {
        _foundMatch = match;
        _error = match == null ? '相手が見つかりませんでした。しばらくしてからもう一度お試しください' : null;
      });

      if (match != null) {
        ref.invalidate(reversiaMatchHistoryProvider(widget.uid));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startGame(ReversiaMatchResult match) async {
    setState(() => _isStartingGame = true);
    try {
      final isPlayer1 = match.player1Uid == widget.uid;
      final opponentUid = isPlayer1 ? match.player2Uid : match.player1Uid;
      final opponentName =
          isPlayer1 ? match.player2DisplayName : match.player1DisplayName;

      // マッチを見つけた側がSide.firstを持つ。
      final game = await ref.read(createReversiaPvpGameProvider)(
        firstUid: widget.uid,
        firstDisplayName: widget.displayName,
        secondUid: opponentUid,
        secondDisplayName: opponentName,
        matchId: match.id,
      );

      await ref.read(attachReversiaGameToMatchProvider)(match.id, game.id);

      try {
        await ref.read(notificationServiceProvider).send(
              uid: opponentUid,
              title: '${widget.displayName}さんと対局が始まりました',
              body: 'タップして対局を開く',
              type: 'pvp_challenge',
              data: {'gameId': game.id},
            );
      } catch (_) {
        // best-effort: 通知に失敗しても対局自体は成立している
      }

      if (!mounted) return;
      ref.invalidate(reversiaMatchHistoryProvider(widget.uid));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReversiaPvpGameScreen(gameId: game.id)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('対局の開始に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingGame = false);
    }
  }
}
