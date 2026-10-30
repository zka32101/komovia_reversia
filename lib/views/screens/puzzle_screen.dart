import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/reversia_move_feedback.dart';
import '../../viewmodels/index.dart';

/// 「今日の1局」: `reversiaPuzzleForDate`で選ばれる、全プレイヤーが同じ日に
/// 同じパズルを見る（Wordle的な）1日1題。すべてのパズルの解は
/// `solution`がちょうど1手（キングを捕獲する一手）であることを
/// `reversia_puzzle_test.dart`で検証済みなので、UI側は「1手だけ入力させ、
/// それが`solution.first`と一致するか」だけを見れば済む。
///
/// サインイン済みであれば、挑戦結果を`ReversiaPuzzleLogService`で記録し
/// 連続解答日数(streak)を表示する（best-effort - 失敗してもパズル自体は
/// 遊べる。GoEnの`tsumeGoStreakProvider`と同じ役割）。
class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

enum _PuzzleOutcome { none, correct, incorrect }

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  final _game = ReversiaGame();
  final _renderer = ReversiaBoardRenderer();
  late final Puzzle<ReversiaPosition> _puzzle =
      reversiaPuzzleForDate(DateTime.now());
  late final String _dateKey = formatReversiaPuzzleDateKey(DateTime.now());

  Square? _selected;
  List<Square> _hints = const [];
  _PuzzleOutcome _outcome = _PuzzleOutcome.none;

  BoardMove get _solutionMove => _puzzle.solution.single as BoardMove;

  Future<void> _recordAttempt(bool correct) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      // その日の問題がまだ未解決かどうかを先に見ておく - 一度解いた後に
      // リセットして再度正解しても、ランキングの`puzzlesSolved`を
      // 二重に加算しないようにする（ログ自体の`solved`はログ側で
      // 既に同じガードを持つが、こちらは別カウンターなので同じガードを
      // ここでも行う必要がある）。
      final existingLog = await ref
          .read(reversiaPuzzleLogServiceProvider)
          .getLog(uid, _dateKey);
      final wasAlreadySolved = existingLog?.solved ?? false;

      await ref.read(recordReversiaPuzzleAttemptProvider)(
        uid: uid,
        dateKey: _dateKey,
        correct: correct,
      );
      ref.invalidate(reversiaPuzzleStreakProvider(uid));

      if (correct && !wasAlreadySolved) {
        final displayName = 'Player ${uid.substring(0, 6)}';
        await ref.read(leaderboardServiceProvider).incrementStats(
              uid: uid,
              displayName: displayName,
              puzzlesDelta: 1,
            );
        await ref.read(checkAndUnlockAchievementsProvider)(uid);
      }
    } catch (_) {
      // best-effort: パズル自体の結果表示はブロックしない
    }
  }

  void _reset() {
    setState(() {
      _selected = null;
      _hints = const [];
      _outcome = _PuzzleOutcome.none;
    });
  }

  void _onTapSquare(Square square) {
    if (_outcome != _PuzzleOutcome.none) return;

    if (_selected == null) {
      final legalFromHere = _game
          .legalMoves(_puzzle.position)
          .whereType<BoardMove>()
          .where((m) => m.from == square)
          .toList();
      if (legalFromHere.isNotEmpty) {
        setState(() {
          _selected = square;
          _hints = legalFromHere.map((m) => m.to).toList();
        });
      }
      return;
    }

    final attempted = BoardMove(from: _selected!, to: square);
    final correct = attempted == _solutionMove;
    if (correct) {
      playReversiaCaptureFeedback();
    } else {
      playReversiaIllegalMoveFeedback();
    }
    setState(() {
      _outcome = correct ? _PuzzleOutcome.correct : _PuzzleOutcome.incorrect;
      _selected = null;
      _hints = const [];
    });
    _recordAttempt(correct);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final difficulty = _puzzle.metadata['difficultyLabel'] as String?;
    final uid = ref.watch(currentUidProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyPuzzleTooltip)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (uid != null) _StreakChip(uid: uid),
              Text(
                difficulty == null
                    ? l10n.puzzleFindKingCaptureMessage
                    : l10n.puzzleDifficultyLabel(difficulty),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _OutcomeBanner(outcome: _outcome),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize =
                        constraints.maxWidth.clamp(0, 400).toDouble();
                    return GestureDetector(
                      key: const Key('puzzle_board_gesture_detector'),
                      onTapUp: (details) {
                        final square = _renderer.squareAt(
                          BoardOffset(
                            details.localPosition.dx,
                            details.localPosition.dy,
                          ),
                          BoardSize(boardSize, boardSize),
                          _puzzle.position,
                        );
                        if (square != null) _onTapSquare(square);
                      },
                      child: SizedBox(
                        width: boardSize,
                        child: _renderer.build(
                          _puzzle.position,
                          hints: _hints,
                          selected: _selected,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_outcome == _PuzzleOutcome.incorrect)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton(
                    onPressed: _reset,
                    child: Text(l10n.playAgainButton),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends ConsumerWidget {
  const _StreakChip({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(reversiaPuzzleStreakProvider(uid)).value;
    if (streak == null || streak == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Chip(
        avatar: const Icon(Icons.local_fire_department, size: 18),
        label: Text(AppLocalizations.of(context)!.puzzleStreakLabel(streak)),
      ),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.outcome});

  final _PuzzleOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (outcome) {
      case _PuzzleOutcome.none:
        return Text(l10n.puzzleTapToSelectMessage);
      case _PuzzleOutcome.correct:
        return Text(
          l10n.puzzleCorrectMessage,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      case _PuzzleOutcome.incorrect:
        return Text(
          l10n.puzzleIncorrectMessage,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }
}
