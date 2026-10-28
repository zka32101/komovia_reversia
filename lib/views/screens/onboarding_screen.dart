import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import '../../services/onboarding_service.dart';

/// この画面の3ステップ。komovia_shogiの`OnboardingScreen`と同じ構造
/// （`komovia_core`の`OnboardingStep`/`OnboardingProgress`上に構築） -
/// このファイルの責務はステップを実際のウィジェットに描画することと、
/// 最後のステップの本物のインタラクティブデモ（駒を取る）だけ。
///
/// komovia_shogiと違い、このアプリはまだFirebase/Riverpodのどちらにも
/// 依存していない（pubspec.yaml参照）ため、[OnboardingService]は
/// Providerを経由せず直接構築して使う。
const _steps = [
  OnboardingStep(
    id: 'how-to-move',
    title: '駒の動かし方',
    body: '表向きの駒は直交に1マス、裏向きの駒は対角に2マスジャンプします。'
        '駒をタップすると、動かせるマスがハイライトされます。',
    icon: 'touch_app',
  ),
  OnboardingStep(
    id: 'win-condition',
    title: '勝敗',
    body: '相手の駒がいる場所へ移動すると、その駒を奪って自分の色に変えます'
        '（石を裏返す点がオセロ的です）。相手のキングを奪うと即座に勝利します。',
    icon: 'emoji_events_outlined',
  ),
  OnboardingStep(
    id: 'capture-demo',
    title: '実際にやってみる',
    body: '表向きの駒をタップして、すぐ上の相手の駒を取ってみましょう',
    requiresExplicitCompletion: true,
  ),
];

IconData? _iconFor(String? name) {
  switch (name) {
    case 'touch_app':
      return Icons.touch_app;
    case 'emoji_events_outlined':
      return Icons.emoji_events_outlined;
    default:
      return null;
  }
}

/// 初回起動時だけ表示する、最短で「駒を取る」体験までたどり着く一回限りの
/// ルール説明。komovia_shogiの`OnboardingScreen`と同じ3ステップ構成
/// （駒の動かし方→勝敗条件→実際に駒を取ってみる）。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  /// オンボーディング完了後（「はじめる」タップ後）に呼ばれるコールバック。
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _onboardingService = OnboardingService();
  OnboardingProgress _progress = const OnboardingProgress(steps: _steps);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _progress = _progress.advance());
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onDemoCaptured() {
    setState(() => _progress = _progress.markStepCompleted('capture-demo'));
  }

  Future<void> _finish() async {
    setState(() => _progress = _progress.advance());
    await _onboardingService.markOnboardingCompleted();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RulesCard(step: _steps[0], onNext: _next),
                  _RulesCard(step: _steps[1], onNext: _next),
                  _CaptureDemoCard(
                    step: _steps[2],
                    captured:
                        _progress.completedStepIds.contains('capture-demo'),
                    onCaptured: _onDemoCaptured,
                    onFinished: _finish,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _progress.currentIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.step, required this.onNext});

  final OnboardingStep step;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(step.icon);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
            ],
            Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              step.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onNext, child: const Text('次へ')),
          ],
        ),
      ),
    );
  }
}

/// オンボーディング最後のページ: 実際にタップして1枚取ってみる体験。
/// `onboardingDemoPosition()`は「表向きの駒がすぐ上の相手の駒を
/// すぐ取れる」だけの最小構成 - 1タップで駒を選び、もう1タップで取る、
/// という最短の「あっ」体験にする。
class _CaptureDemoCard extends StatefulWidget {
  const _CaptureDemoCard({
    required this.step,
    required this.captured,
    required this.onCaptured,
    required this.onFinished,
  });

  final OnboardingStep step;
  final bool captured;
  final VoidCallback onCaptured;
  final Future<void> Function() onFinished;

  @override
  State<_CaptureDemoCard> createState() => _CaptureDemoCardState();
}

class _CaptureDemoCardState extends State<_CaptureDemoCard> {
  final _renderer = ReversiaBoardRenderer();
  final _game = ReversiaGame();
  late ReversiaPosition _position = onboardingDemoPosition();
  Square? _selected;
  List<Square> _hints = const [];

  void _onTapSquare(Square square) {
    if (widget.captured) return;
    if (_selected == null) {
      final legal = _game
          .legalMoves(_position)
          .whereType<BoardMove>()
          .where((m) => m.from == square)
          .toList();
      if (legal.isNotEmpty) {
        setState(() {
          _selected = square;
          _hints = legal.map((m) => m.to).toList();
        });
      }
      return;
    }
    if (square == onboardingDemoCaptureMove.to) {
      setState(() {
        _position = _game.apply(_position, onboardingDemoCaptureMove);
        _selected = null;
        _hints = const [];
      });
      widget.onCaptured();
    } else {
      setState(() {
        _selected = null;
        _hints = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.captured ? 'やった、1枚取れました！' : widget.step.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = constraints.maxWidth.clamp(0, 320).toDouble();
                return GestureDetector(
                  key: const Key('onboarding_board_gesture_detector'),
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
                      hints: _hints,
                      selected: _selected,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (widget.captured)
              Text(
                '取った駒は自分の色になります。相手のキングを奪うと勝利です。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.captured ? widget.onFinished : null,
              child: const Text('はじめる'),
            ),
          ],
        ),
      ),
    );
  }
}
