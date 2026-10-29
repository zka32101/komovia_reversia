import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import 'firebase_options.dart';
import 'services/onboarding_service.dart';
import 'viewmodels/index.dart';
import 'views/screens/leaderboard_screen.dart';
import 'views/screens/notification_screen.dart';
import 'views/screens/onboarding_screen.dart';
import 'views/screens/puzzle_screen.dart';
import 'views/screens/reversia_game_review_screen.dart';
import 'views/screens/reversia_matching_screen.dart';

/// komovia_reversia's app shell: a single local human-vs-AI game screen
/// exercising `ReversiaGame`/`ReversiaEngine`/`ReversiaBoardRenderer` end
/// to end, following the priority order in the package README ("app
/// shell first, then onboarding, then daily-puzzle UI, then Firebase
/// social wiring" — see also `komovia_shogi`'s `main.dart` as the
/// pattern this mirrors).
///
/// Firebase/Riverpod are now wired in (this is the "Firebase social
/// wiring" step from that priority order), with placeholder config
/// (`firebase_options.dart`) until `flutterfire configure` is run against
/// a real project — the point of this step is only to lay the same
/// foundation komovia_shogi/komovia_go already had before their PvP
/// features were built; no social/PvP screens exist yet.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Placeholder Firebase config won't actually initialize against a real
    // backend; swallow so the app still runs standalone.
  }
  runApp(const ProviderScope(child: KomoviaReversiaApp()));
}

class KomoviaReversiaApp extends StatelessWidget {
  const KomoviaReversiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Komovia Reversia',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const _RootScreen(),
    );
  }
}

/// 初回起動時だけ`OnboardingScreen`を表示し、完了済み（または完了直後）
/// なら`ReversiaGameScreen`へ進む — komovia_shogiの`_RootScreen`と同じ
/// 役割。サインイン（匿名）はバックグラウンドで行い、オンボーディング・
/// 対局自体はその完了を待たない（将来の社交/PvP機能が必要になった時点で
/// uidを使えばよい）。
class _RootScreen extends ConsumerStatefulWidget {
  const _RootScreen();

  @override
  ConsumerState<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<_RootScreen> {
  final _onboardingService = OnboardingService();
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
    _onboardingService.hasCompletedOnboarding().then((completed) {
      if (mounted) setState(() => _hasCompletedOnboarding = completed);
    });
  }

  Future<void> _ensureSignedIn() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await ref.read(authServiceProvider).signInAnonymously();
      }
    } catch (_) {
      // No real Firebase project configured yet.
    }
  }

  void _onOnboardingFinished() {
    setState(() => _hasCompletedOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _hasCompletedOnboarding;
    if (completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!completed) {
      return OnboardingScreen(onFinished: _onOnboardingFinished);
    }
    return const ReversiaGameScreen();
  }
}

/// A single local game: the player is always [Side.first] (前row,
/// matching `ReversiaGame.initialPosition`'s placement), the AI always
/// [Side.second]. Tap a piece to select it (legal destinations
/// highlight), tap a destination to move; the AI replies automatically
/// after a short delay once the position is its turn.
class ReversiaGameScreen extends ConsumerStatefulWidget {
  const ReversiaGameScreen({super.key});

  @override
  ConsumerState<ReversiaGameScreen> createState() =>
      _ReversiaGameScreenState();
}

class _ReversiaGameScreenState extends ConsumerState<ReversiaGameScreen> {
  static const _aiLevel = 2;

  final _game = ReversiaGame();
  final _engine = ReversiaEngine();
  final _renderer = ReversiaBoardRenderer();

  late ReversiaPosition _position = _game.initialPosition();
  late ReversiaPosition _initialPosition = _position;
  final List<Object> _historyKeys = [];
  final List<RecordedMove> _moveRecord = [];
  Square? _selected;
  List<Square> _hints = const [];
  Move? _lastMove;
  bool _aiThinking = false;
  Timer? _aiMoveTimer;

  GameResult get _result =>
      _game.result(_position, historyKeys: _historyKeys);

  @override
  void initState() {
    super.initState();
    _historyKeys.add(_game.positionKey(_position));
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    super.dispose();
  }

  void _newGame() {
    _aiMoveTimer?.cancel();
    setState(() {
      _position = _game.initialPosition();
      _initialPosition = _position;
      _historyKeys.clear();
      _historyKeys.add(_game.positionKey(_position));
      _moveRecord.clear();
      _selected = null;
      _hints = const [];
      _lastMove = null;
      _aiThinking = false;
    });
  }

  void _applyMove(Move move) {
    final mover = _position.sideToMove;
    setState(() {
      _moveRecord.add(RecordedMove(
        number: _moveRecord.length + 1,
        side: mover,
        move: move,
      ));
      _position = _game.apply(_position, move, historyKeys: _historyKeys);
      _historyKeys.add(_game.positionKey(_position));
      _lastMove = move;
      _selected = null;
      _hints = const [];
    });
    final result = _result;
    if (!result.isOngoing) {
      ref.read(updateReversiaRatingAfterGameProvider)(result, _aiLevel);
    }
    _maybeScheduleAiMove();
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReversiaGameReviewScreen(
          initialPosition: _initialPosition,
          moves: List.of(_moveRecord),
          humanSide: Side.first,
        ),
      ),
    );
  }

  /// 競合アプリの多くが標準機能として持つヒント — `ReversiaEvaluator`
  /// （AI探索・振り返り機能と同じ評価関数）で現局面の最善手を1つ求め、
  /// 通常のタップ選択と同じ`_selected`/`_hints`でハイライトする（自動で
  /// は着手しない。着手するかどうかは依然プレイヤー自身が選ぶ）。
  void _showHint() {
    if (_aiThinking || !_result.isOngoing) return;
    if (_position.sideToMove != Side.first) return;

    final best = bestLegalMove(
      _game,
      ReversiaEvaluator(_game),
      _position,
      Side.first,
      historyKeys: _historyKeys,
    );
    if (best == null) return;

    setState(() {
      _selected = best.from;
      _hints = [best.to];
    });
  }

  void _maybeScheduleAiMove() {
    if (!_result.isOngoing) return;
    if (_position.sideToMove != Side.second) return;
    setState(() => _aiThinking = true);
    _aiMoveTimer = Timer(const Duration(milliseconds: 400), () async {
      final move = await _engine.bestMove(_position, level: _aiLevel);
      if (!mounted) return;
      setState(() => _aiThinking = false);
      if (move != null) _applyMove(move);
    });
  }

  void _onTapSquare(Square square) {
    if (_aiThinking || !_result.isOngoing) return;
    if (_position.sideToMove != Side.first) return;

    if (_selected != null && _hints.contains(square)) {
      _applyMove(BoardMove(from: _selected!, to: square));
      return;
    }

    final piece = _position.at(square);
    if (piece != null && piece.owner == Side.first) {
      final legal = _game
          .legalMoves(_position, historyKeys: _historyKeys)
          .whereType<BoardMove>()
          .where((m) => m.from == square)
          .toList();
      setState(() {
        _selected = square;
        _hints = legal.map((m) => m.to).toList();
      });
    } else {
      setState(() {
        _selected = null;
        _hints = const [];
      });
    }
  }

  String get _statusText {
    final result = _result;
    if (result.isOngoing) {
      if (_aiThinking) return 'AIが考えています…';
      return _position.sideToMove == Side.first ? 'あなたの番です' : '相手の番です';
    }
    if (result.kind == ResultKind.draw) return '引き分けです';
    final youWon = result.winner == Side.first;
    return youWon ? 'あなたの勝ちです！' : 'あなたの負けです';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komovia Reversia'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final uid = ref.watch(currentUidProvider);
              if (uid == null) return const SizedBox.shrink();
              return Stack(
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
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final uid = ref.watch(currentUidProvider);
              return IconButton(
                icon: const Icon(Icons.group),
                tooltip: '対局相手を探す',
                onPressed: uid == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReversiaMatchingScreen(
                              uid: uid,
                              displayName: 'Player ${uid.substring(0, 6)}',
                            ),
                          ),
                        ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'ヒント',
            onPressed:
                (_result.isOngoing && !_aiThinking && _position.sideToMove == Side.first)
                    ? _showHint
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'ランキング',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '今日の1局',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PuzzleScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '新しい対局',
            onPressed: _newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_statusText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.maxWidth.clamp(0, 400).toDouble();
                    return GestureDetector(
                      key: const Key('reversia_board_gesture_detector'),
                      onTapUp: (details) {
                        final square = _renderer.squareAt(
                          BoardOffset(
                            details.localPosition.dx,
                            details.localPosition.dy,
                          ),
                          BoardSize(boardSize, boardSize),
                          _position,
                        );
                        if (square != null) _onTapSquare(square);
                      },
                      child: SizedBox(
                        width: boardSize,
                        child: _renderer.build(
                          _position,
                          lastMove: _lastMove,
                          hints: _hints,
                          selected: _selected,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_result.isOngoing) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton(
                    onPressed: _newGame,
                    child: const Text('もう一度'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _moveRecord.isEmpty ? null : _openReview,
                    child: const Text('対局を振り返る'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
