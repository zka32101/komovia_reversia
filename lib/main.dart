import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import 'services/onboarding_service.dart';
import 'views/screens/onboarding_screen.dart';
import 'views/screens/puzzle_screen.dart';

/// komovia_reversia's app shell: a single local human-vs-AI game screen
/// exercising `ReversiaGame`/`ReversiaEngine`/`ReversiaBoardRenderer` end
/// to end, following the priority order in the package README ("app
/// shell first, then onboarding, then daily-puzzle UI, then Firebase
/// social wiring" — see also `komovia_shogi`'s `main.dart` as the
/// pattern this mirrors).
///
/// No Firebase, no Riverpod, no social features yet — this app has no
/// such dependency at all today (see pubspec.yaml), and the point of
/// this first step is only to make the already-complete `Game`/`Engine`/
/// `BoardRenderer` stack actually playable.
void main() {
  runApp(const KomoviaReversiaApp());
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
/// 役割だが、このアプリにはまだFirebase/サインインが無いため、その部分は
/// 単純化している。
class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  final _onboardingService = OnboardingService();
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _onboardingService.hasCompletedOnboarding().then((completed) {
      if (mounted) setState(() => _hasCompletedOnboarding = completed);
    });
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
class ReversiaGameScreen extends StatefulWidget {
  const ReversiaGameScreen({super.key});

  @override
  State<ReversiaGameScreen> createState() => _ReversiaGameScreenState();
}

class _ReversiaGameScreenState extends State<ReversiaGameScreen> {
  final _game = ReversiaGame();
  final _engine = ReversiaEngine();
  final _renderer = ReversiaBoardRenderer();

  late ReversiaPosition _position = _game.initialPosition();
  final List<Object> _historyKeys = [];
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
      _historyKeys.clear();
      _historyKeys.add(_game.positionKey(_position));
      _selected = null;
      _hints = const [];
      _lastMove = null;
      _aiThinking = false;
    });
  }

  void _applyMove(Move move) {
    setState(() {
      _position = _game.apply(_position, move, historyKeys: _historyKeys);
      _historyKeys.add(_game.positionKey(_position));
      _lastMove = move;
      _selected = null;
      _hints = const [];
    });
    _maybeScheduleAiMove();
  }

  void _maybeScheduleAiMove() {
    if (!_result.isOngoing) return;
    if (_position.sideToMove != Side.second) return;
    setState(() => _aiThinking = true);
    _aiMoveTimer = Timer(const Duration(milliseconds: 400), () async {
      final move = await _engine.bestMove(_position, level: 2);
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
              if (!_result.isOngoing)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton(
                    onPressed: _newGame,
                    child: const Text('もう一度'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
