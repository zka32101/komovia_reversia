import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

/// 「今日の1局」: `reversiaPuzzleForDate`で選ばれる、全プレイヤーが同じ日に
/// 同じパズルを見る（Wordle的な）1日1題。すべてのパズルの解は
/// `solution`がちょうど1手（キングを捕獲する一手）であることを
/// `reversia_puzzle_test.dart`で検証済みなので、UI側は「1手だけ入力させ、
/// それが`solution.first`と一致するか」だけを見れば済む。
///
/// README記載の優先順位（アプリ本体→オンボーディング→今日の1局UI→
/// Firebase連携）の次の段取り - このアプリにはまだFirebase/Riverpod
/// 依存が無いため、「解いたかどうか」の永続化・連続日数記録等は含めない
/// （Firebase連携が入った後の話）。
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

enum _PuzzleOutcome { none, correct, incorrect }

class _PuzzleScreenState extends State<PuzzleScreen> {
  final _game = ReversiaGame();
  final _renderer = ReversiaBoardRenderer();
  late final Puzzle<ReversiaPosition> _puzzle =
      reversiaPuzzleForDate(DateTime.now());

  Square? _selected;
  List<Square> _hints = const [];
  _PuzzleOutcome _outcome = _PuzzleOutcome.none;

  BoardMove get _solutionMove => _puzzle.solution.single as BoardMove;

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
    setState(() {
      _outcome = attempted == _solutionMove
          ? _PuzzleOutcome.correct
          : _PuzzleOutcome.incorrect;
      _selected = null;
      _hints = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final difficulty = _puzzle.metadata['difficultyLabel'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('今日の1局')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                difficulty == null ? 'キングを捕獲する一手を探しましょう' : '難易度: $difficulty',
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

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.outcome});

  final _PuzzleOutcome outcome;

  @override
  Widget build(BuildContext context) {
    switch (outcome) {
      case _PuzzleOutcome.none:
        return const Text('駒をタップして選び、行き先をタップしてください');
      case _PuzzleOutcome.correct:
        return Text(
          '正解です！',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      case _PuzzleOutcome.incorrect:
        return Text(
          '残念、違う手です',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }
}
