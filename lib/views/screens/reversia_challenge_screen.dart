import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reversia_challenge_code.dart';
import '../../viewmodels/index.dart';
import 'reversia_pvp_game_screen.dart';

/// フレンド対戦（招待コード）画面。`ReversiaMatchingScreen`の不特定
/// 相手とのランダムマッチングとは別に、特定の相手（アプリ外で合言葉を
/// 伝えられる間柄）を指名して対戦するための導線。フレンド機能自体は
/// まだ無いため、Piccolo: Othelloなどの競合アプリが採用する「共有
/// コード方式」（ランクには影響しない）を採用した。
///
/// どちらの側も[_activeCode]を監視し、[ReversiaChallengeCode.gameId]が
/// 付与された時点で対局画面へ遷移する。実際にPvpGameを作成するのは
/// ホスト側（コードの監視でゲスト参加(matched)を検知した側）のみ —
/// ゲスト側が同時に作成を試みて対局が2つできることはない。
class ReversiaChallengeScreen extends ConsumerStatefulWidget {
  const ReversiaChallengeScreen({
    super.key,
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;

  @override
  ConsumerState<ReversiaChallengeScreen> createState() =>
      _ReversiaChallengeScreenState();
}

class _ReversiaChallengeScreenState extends ConsumerState<ReversiaChallengeScreen> {
  final _codeController = TextEditingController();
  String? _activeCode;
  bool _isHost = false;
  bool _isCreating = false;
  bool _isJoining = false;
  String? _error;
  bool _gameCreationStarted = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createCode() async {
    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(createReversiaChallengeProvider)(
        hostUid: widget.uid,
        hostDisplayName: widget.displayName,
      );
      if (!mounted) return;
      setState(() {
        _activeCode = challenge.code;
        _isHost = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '対局コードの発行に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isJoining = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(joinReversiaChallengeProvider)(
        code: code,
        guestUid: widget.uid,
        guestDisplayName: widget.displayName,
      );
      if (!mounted) return;
      if (challenge == null) {
        setState(() => _error = 'このコードは無効、または既に使用されています');
      } else {
        setState(() {
          _activeCode = challenge.code;
          _isHost = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '参加に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// ゲストが参加した(matched)ことをホスト側が検知したら、PvpGameを
  /// 作成してコードに紐付ける。`PvpGameService.createGameForTournamentMatch`
  /// と同種の「既に作成済みならスキップ」ガード（[_gameCreationStarted]）
  /// で、このコールバックが複数回呼ばれても対局は1つしか作られない。
  Future<void> _maybeCreateGame(ReversiaChallengeCode challenge) async {
    if (!_isHost) return;
    if (challenge.status != 'matched') return;
    if (challenge.gameId != null) return;
    if (challenge.guestUid == null) return;
    if (_gameCreationStarted) return;
    _gameCreationStarted = true;

    try {
      final game = await ref.read(createReversiaPvpGameProvider)(
        firstUid: challenge.hostUid,
        firstDisplayName: challenge.hostDisplayName,
        secondUid: challenge.guestUid!,
        secondDisplayName: challenge.guestDisplayName ?? 'Player',
      );
      await ref.read(attachReversiaGameToChallengeProvider)(
        challenge.code,
        game.id,
      );

      try {
        await ref.read(notificationServiceProvider).send(
              uid: challenge.guestUid!,
              title: '${challenge.hostDisplayName}さんと対局が始まりました',
              body: 'タップして対局を開く',
              type: 'pvp_challenge',
              data: {'gameId': game.id},
            );
      } catch (_) {
        // best-effort: 通知に失敗しても対局自体は成立している
      }
    } catch (_) {
      _gameCreationStarted = false; // 失敗したら次の通知で再試行できるように
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _activeCode;
    if (code != null) {
      ref.listen(reversiaChallengeStreamProvider(code), (previous, next) {
        final challenge = next.value;
        if (challenge == null) return;
        _maybeCreateGame(challenge);
        if (challenge.gameId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReversiaPvpGameScreen(gameId: challenge.gameId!),
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('フレンド対戦')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (code != null) _buildWaitingCard(code),
            if (code == null) ...[
              const Text('対局コードを発行して相手に伝えるか、相手から伝えられたコードを入力してください。'),
              const SizedBox(height: 20),
              Text(
                '対局コードを発行する',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isCreating ? null : _createCode,
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('コードを発行する'),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'コードで参加する',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '対局コード',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isJoining ? null : _joinCode,
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('参加する'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingCard(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isHost ? 'このコードを相手に伝えてください' : '対局相手を待っています…'),
          const SizedBox(height: 12),
          Text(
            code,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('相手が参加すると自動的に対局が始まります'),
            ],
          ),
        ],
      ),
    );
  }
}
