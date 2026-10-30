import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import '../../l10n/app_localizations.dart';
import '../../services/onboarding_service.dart';

/// この画面の3ステップ。komovia_shogiの`OnboardingScreen`と同じ構造
/// （`komovia_core`の`OnboardingStep`/`OnboardingProgress`上に構築） -
/// このファイルの責務はステップを実際のウィジェットに描画することと、
/// 最後のステップの本物のインタラクティブデモ（駒を取る）だけ。
///
/// komovia_shogiと違い、このアプリはまだFirebase/Riverpodのどちらにも
/// 依存していない（pubspec.yaml参照）ため、[OnboardingService]は
/// Providerを経由せず直接構築して使う。
List<OnboardingStep> _steps(AppLocalizations l10n) => [
      OnboardingStep(
        id: 'how-to-move',
        title: l10n.onboardingHowToMoveTitle,
        body: l10n.onboardingHowToMoveBody,
        icon: 'touch_app',
      ),
      OnboardingStep(
        id: 'win-condition',
        title: l10n.onboardingWinConditionTitle,
        body: l10n.onboardingWinConditionBody,
        icon: 'emoji_events_outlined',
      ),
      OnboardingStep(
        id: 'capture-demo',
        title: l10n.onboardingCaptureDemoTitle,
        body: l10n.onboardingCaptureDemoBody,
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
  late List<OnboardingStep> _localizedSteps;
  late OnboardingProgress _progress;
  bool _stepsInitialized = false;

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
    final l10n = AppLocalizations.of(context)!;
    if (!_stepsInitialized) {
      _localizedSteps = _steps(l10n);
      _progress = OnboardingProgress(steps: _localizedSteps);
      _stepsInitialized = true;
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RulesCard(step: _localizedSteps[0], onNext: _next),
                  _RulesCard(step: _localizedSteps[1], onNext: _next),
                  _CaptureDemoCard(
                    step: _localizedSteps[2],
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
                  _localizedSteps.length,
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
            FilledButton(
              onPressed: onNext,
              child: Text(AppLocalizations.of(context)!.onboardingNextButton),
            ),
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.captured ? l10n.onboardingCapturedMessage : widget.step.body,
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
                l10n.onboardingCapturedFollowUpMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.captured ? widget.onFinished : null,
              child: Text(l10n.onboardingStartButton),
            ),
          ],
        ),
      ),
    );
  }
}
