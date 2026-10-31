import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/reversia_pvp_game.dart';
import '../../services/reversia_pvp_game_service.dart';
import '../../viewmodels/index.dart';
import 'reversia_pvp_game_screen.dart';

/// 進行中のPvP対局一覧。マッチング・招待コードから対局を始めた後、
/// 通知やマッチ履歴を経由せず直接戻ってこられる専用画面
/// （GoEnの`PvpGamesListScreen`と同じ役割 - `reversiaUserActivePvpGamesProvider`
/// 自体はPvP対局機能と一緒に用意されていたが、これまで専用の一覧画面が
/// 無かった）。
class ReversiaPvpGamesListScreen extends ConsumerWidget {
  const ReversiaPvpGamesListScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final gamesAsync = ref.watch(reversiaUserActivePvpGamesProvider(uid));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homePvpGamesTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reversiaUserActivePvpGamesProvider(uid));
          await ref.read(reversiaUserActivePvpGamesProvider(uid).future);
        },
        child: gamesAsync.when(
          data: (games) {
            if (games.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(child: Text(l10n.pvpGamesListEmptyMessage)),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: games.length,
              itemBuilder: (context, index) =>
                  _GameCard(game: games[index], uid: uid),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.commonErrorMessage(err.toString()),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends ConsumerWidget {
  const _GameCard({required this.game, required this.uid});

  final ReversiaPvpGame game;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isFirst = game.playerColorOf(uid) == 1;
    final opponentName = isFirst ? game.secondDisplayName : game.firstDisplayName;
    final myTurn = game.isTurnOf(uid);
    final canClaimForfeit = game.canClaimAbandonmentForfeit(
      uid,
      policy: ReversiaPvpGameService.abandonmentPolicy,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: myTurn
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : null,
              child: const Icon(Icons.person),
            ),
            title: Text(l10n.pvpGamesListOpponentLabel(opponentName)),
            subtitle: Text(
              '${l10n.pvpGamesListMovesCountLabel(game.movesCount)}'
              '${canClaimForfeit ? '\n${l10n.pvpGamesListOpponentInactiveMessage}' : ''}',
              style: canClaimForfeit
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
            isThreeLine: canClaimForfeit,
            trailing: myTurn
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(l10n.pvpGamesListYourTurnLabel),
                  )
                : Text(l10n.pvpGamesListOpponentTurnLabel),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReversiaPvpGameScreen(gameId: game.id),
              ),
            ),
          ),
          if (canClaimForfeit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => _confirmClaimForfeit(context, ref),
                  child: Text(l10n.pvpGamesListClaimForfeitButton),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClaimForfeit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pvpGamesListClaimForfeitDialogTitle),
        content: Text(l10n.pvpGamesListClaimForfeitDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.pvpGamesListClaimForfeitConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(claimReversiaAbandonmentForfeitProvider)(game.id, uid);
      ref.invalidate(reversiaUserActivePvpGamesProvider(uid));
    } catch (_) {
      // best-effort: 失敗しても一覧自体の表示はブロックしない
    }
  }
}
