import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import '../../l10n/app_localizations.dart';
import '../../models/reversia_pvp_game.dart';
import '../../services/reversia_pvp_game_service.dart';
import '../../utils/reversia_move_feedback.dart';
import '../../viewmodels/index.dart';
import 'reversia_game_review_screen.dart';

/// PvP対局画面。main.dartの`ReversiaGameScreen`（AI対局）と同じタップ
/// 操作（駒をタップ→合法手ハイライト→タップで着手）だが、盤面は
/// [ReversiaPvpGame.movesRecord]をFirestoreから購読し、他プレイヤーの
/// 着手もリアルタイムに反映される。
class ReversiaPvpGameScreen extends ConsumerStatefulWidget {
  const ReversiaPvpGameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<ReversiaPvpGameScreen> createState() =>
      _ReversiaPvpGameScreenState();
}

class _ReversiaPvpGameScreenState extends ConsumerState<ReversiaPvpGameScreen> {
  final _renderer = ReversiaBoardRenderer();
  final _game = ReversiaGame();

  Square? _selected;
  List<Square> _hints = const [];
  String? _errorMessage;

  /// 放置勝ちの閾値は15分と短く、待っている側は画面を開いたまま待つ
  /// ことが多い。相手が無応答の間はFirestoreのストリームが何も流さない
  /// ため、時間経過だけで申請ボタン・残り時間表示が切り替わるよう、
  /// 定期的に再描画する。
  Timer? _forfeitTicker;

  @override
  void initState() {
    super.initState();
    _forfeitTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _forfeitTicker?.cancel();
    super.dispose();
  }

  /// [ReversiaPvpGame.movesRecord]を初期局面から打ち直して再構成する。
  /// `ReversiaPvpGameService._replay`と同じロジック（盤面をFirestoreへ
  /// 直接保存しない設計である以上、読む側は必ずこの再構成を行う必要が
  /// ある）。
  (ReversiaPosition, List<Object>) _replay(String movesRecord) {
    var position = _game.initialPosition();
    final historyKeys = <Object>[_game.positionKey(position)];
    if (movesRecord.isNotEmpty) {
      final record = _game.importRecord(movesRecord);
      for (final recorded in record.moves) {
        position = _game.apply(position, recorded.move);
        historyKeys.add(_game.positionKey(position));
      }
    }
    return (position, historyKeys);
  }

  Side? _humanSide(ReversiaPvpGame pvp, String uid) {
    final color = pvp.playerColorOf(uid);
    if (color == 1) return Side.first;
    if (color == 2) return Side.second;
    return null;
  }

  void _openReview(ReversiaPvpGame pvp, Side humanSide) {
    // movesRecordは一度も着手されていない対局（即投了など）では空文字列
    // のままなので、`ReversiaPvpGameService._replay`と同じく
    // `importRecord`を呼ぶ前にガードする。
    final moves = pvp.movesRecord.isEmpty
        ? const <RecordedMove>[]
        : _game.importRecord(pvp.movesRecord).moves;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReversiaGameReviewScreen(
          initialPosition: _game.initialPosition(),
          moves: moves,
          humanSide: humanSide,
        ),
      ),
    );
  }

  void _onTapSquare(
    Square square,
    ReversiaPvpGame pvp,
    ReversiaPosition position,
    List<Object> historyKeys,
    String uid,
  ) {
    if (!pvp.isTurnOf(uid)) return;

    final legal = _game.legalMoves(position, historyKeys: historyKeys);
    if (_selected == null) {
      final movesFromHere =
          legal.whereType<BoardMove>().where((m) => m.from == square).toList();
      if (movesFromHere.isNotEmpty) {
        setState(() {
          _selected = square;
          _hints = movesFromHere.map((m) => m.to).toList();
        });
      }
      return;
    }

    final matches = legal
        .whereType<BoardMove>()
        .where((m) => m.from == _selected && m.to == square)
        .toList();
    setState(() {
      _selected = null;
      _hints = const [];
    });
    if (matches.isNotEmpty) {
      final move = matches.first;
      final target = position.at(move.to);
      if (target != null && target.owner != position.sideToMove) {
        playReversiaCaptureFeedback();
      } else {
        playReversiaMovePlaceFeedback();
      }
      _applyMove(move, uid);
    }
  }

  Future<void> _applyMove(Move move, String uid) async {
    final applied =
        await ref.read(applyReversiaPvpMoveProvider)(widget.gameId, uid, move);
    if (!mounted) return;
    if (!applied) {
      playReversiaIllegalMoveFeedback();
      setState(() => _errorMessage =
          AppLocalizations.of(context)!.pvpGameIllegalMoveMessage);
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _confirmResign(String uid) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pvpGameResignDialogTitle),
        content: Text(l10n.pvpGameResignDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pvpGameResignConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(resignReversiaPvpGameProvider)(widget.gameId, uid);
  }

  Future<void> _confirmClaimForfeit(String uid) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pvpGamesListClaimForfeitDialogTitle),
        content: Text(l10n.pvpGamesListClaimForfeitDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pvpGamesListClaimForfeitConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(claimReversiaAbandonmentForfeitProvider)(widget.gameId, uid);
  }

  String _statusText(
      AppLocalizations l10n, ReversiaPvpGame pvp, Side? humanSide) {
    if (pvp.isFinished) {
      if (pvp.winnerUid == null) return l10n.pvpGameFinishedMessage;
      final uid = ref.read(currentUidProvider);
      if (pvp.result == 'forfeit') {
        return uid == pvp.winnerUid
            ? l10n.pvpGameWonByForfeitMessage
            : l10n.pvpGameLostByForfeitMessage;
      }
      if (uid == pvp.winnerUid) return l10n.youWinStatus;
      return l10n.youLoseStatus;
    }
    if (humanSide == null) return l10n.pvpGameSpectatingStatus;
    return pvp.isTurnOf(ref.read(currentUidProvider) ?? '')
        ? l10n.yourTurnStatus
        : l10n.opponentTurnStatus;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.watch(currentUidProvider);
    final gameAsync = ref.watch(reversiaPvpGameStreamProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pvpGameTitle)),
      body: gameAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(l10n.growthLoadFailedMessage(error.toString()))),
        data: (pvp) {
          if (uid == null) {
            return Center(child: Text(l10n.pvpGameLoginRequiredMessage));
          }
          final (position, historyKeys) = _replay(pvp.movesRecord);
          final humanSide = _humanSide(pvp, uid);

          final forfeitRemaining = pvp.abandonmentForfeitRemaining(
            uid,
            policy: ReversiaPvpGameService.abandonmentPolicy,
          );

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _statusText(l10n, pvp, humanSide),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boardSize =
                              constraints.maxWidth.clamp(0, 400).toDouble();
                          return GestureDetector(
                            key: const Key(
                                'reversia_pvp_board_gesture_detector'),
                            onTapUp: (details) {
                              final square = _renderer.squareAt(
                                BoardOffset(
                                  details.localPosition.dx,
                                  details.localPosition.dy,
                                ),
                                BoardSize(boardSize, boardSize),
                                position,
                                // 後手視点では盤面を反転表示するので、タップ
                                // 判定も同じ向きで逆変換する必要がある。
                                flipped: humanSide == Side.second,
                              );
                              if (square != null) {
                                _onTapSquare(
                                  square,
                                  pvp,
                                  position,
                                  historyKeys,
                                  uid,
                                );
                              }
                            },
                            child: SizedBox(
                              width: boardSize,
                              child: _renderer.build(
                                position,
                                hints: _hints,
                                selected: _selected,
                                // 両プレイヤーが常に自分の駒を手元（画面下側）
                                // に見られるよう、後手は盤面を自動で反転する
                                // - competitor Othello/Reversiアプリによく
                                // ある「自分視点で見る」機能。観戦中
                                // (humanSide == null)は反転しない。
                                flipped: humanSide == Side.second,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (pvp.isActive && humanSide != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          onPressed: () => _confirmResign(uid),
                          child: Text(l10n.pvpGameResignButton),
                        ),
                      ),
                    if (pvp.isFinished && humanSide != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          onPressed: () => _openReview(pvp, humanSide),
                          child: Text(l10n.reviewGameButton),
                        ),
                      ),
                    if (forfeitRemaining != null &&
                        forfeitRemaining > Duration.zero)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l10n.pvpGameForfeitAvailableInMessage(
                            // 端数は切り上げて「あと0分」と表示しない
                            (forfeitRemaining.inSeconds / 60).ceil(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (pvp.canClaimAbandonmentForfeit(
                      uid,
                      policy: ReversiaPvpGameService.abandonmentPolicy,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            Text(
                              l10n.pvpGamesListOpponentInactiveMessage,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () => _confirmClaimForfeit(uid),
                              child: Text(l10n.pvpGamesListClaimForfeitButton),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
