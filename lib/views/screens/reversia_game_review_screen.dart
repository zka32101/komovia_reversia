import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import '../../l10n/app_localizations.dart';

/// 対局後の振り返り画面。競合アプリの「棋譜解析」「敗因分析」機能に
/// 相当 — [ReversiaGameAnalyzer]（評価関数ベースの決定的なローカル解析、
/// LLMは使わない）で[humanSide]の全着手を最善手と比較し、一手ごとの
/// 評価と総評を表示する。各着手には自分でタグ・メモを付けられる
/// （[ReversiaMoveAnnotation]参照 - 永続化はせず、この画面を開いている
/// 間だけ保持する）。
class ReversiaGameReviewScreen extends StatefulWidget {
  const ReversiaGameReviewScreen({
    super.key,
    required this.initialPosition,
    required this.moves,
    required this.humanSide,
  });

  final ReversiaPosition initialPosition;
  final List<RecordedMove> moves;
  final Side humanSide;

  @override
  State<ReversiaGameReviewScreen> createState() => _ReversiaGameReviewScreenState();
}

class _ReversiaGameReviewScreenState extends State<ReversiaGameReviewScreen> {
  final Map<int, ReversiaMoveAnnotation> _annotations = {};

  Future<void> _editAnnotation(int moveNumber) async {
    final l10n = AppLocalizations.of(context)!;
    final current = _annotations[moveNumber] ?? const ReversiaMoveAnnotation();
    final controller = TextEditingController(text: current.note);
    var selectedTag = current.tag;

    final result = await showDialog<ReversiaMoveAnnotation?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(l10n.gameReviewMoveNoteDialogTitle(moveNumber)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in ReversiaMoveTag.values)
                      ChoiceChip(
                        label: Text('${tag.emoji} ${tag.label}'),
                        selected: selectedTag == tag,
                        onSelected: (selected) =>
                            setState(() => selectedTag = selected ? tag : null),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.gameReviewNoteLabel),
                ),
              ],
            ),
            actions: [
              if (!current.isEmpty)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, const ReversiaMoveAnnotation()),
                  child: Text(l10n.deleteButton),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l10n.cancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  ReversiaMoveAnnotation(tag: selectedTag, note: controller.text),
                ),
                child: Text(l10n.saveButton),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    setState(() {
      if (result.isEmpty) {
        _annotations.remove(moveNumber);
      } else {
        _annotations[moveNumber] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final analysis = ReversiaGameAnalyzer().analyze(
      initialPosition: widget.initialPosition,
      moves: widget.moves,
      side: widget.humanSide,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameReviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.gameReviewSummaryTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(analysis.summary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (analysis.moveReviews.isNotEmpty) ...[
            _PhaseBreakdownCard(breakdown: analysis.phaseBreakdown),
            const SizedBox(height: 16),
          ],
          if (analysis.moveReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.gameReviewNoMovesMessage),
            )
          else
            ...analysis.moveReviews.map((review) => _MoveReviewTile(
                  review,
                  annotation: _annotations[review.moveNumber],
                  onTap: () => _editAnnotation(review.moveNumber),
                )),
        ],
      ),
    );
  }
}

class _MoveReviewTile extends StatelessWidget {
  const _MoveReviewTile(this.review, {required this.annotation, required this.onTap});

  final ReversiaMoveReview review;
  final ReversiaMoveAnnotation? annotation;
  final VoidCallback onTap;

  Color _qualityColor(BuildContext context) {
    switch (review.quality) {
      case ReversiaMoveQuality.excellent:
      case ReversiaMoveQuality.good:
        return Colors.green;
      case ReversiaMoveQuality.inaccuracy:
        return Colors.orange;
      case ReversiaMoveQuality.mistake:
      case ReversiaMoveQuality.blunder:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tag = annotation?.tag;
    final note = annotation?.note ?? '';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text('${review.moveNumber}')),
      title: Text(
        '${tag != null ? '${tag.emoji} ' : ''}${reversiaMoveNotation(review.move)}  ${review.quality.label}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.lossVsBest > 0)
            Text(l10n.gameReviewLossVsBestLabel(review.lossVsBest)),
          if (review.bestAlternativeMove != null)
            Text(l10n.gameReviewBestMoveLabel(
              reversiaMoveNotation(review.bestAlternativeMove!),
            )),
          if (note.isNotEmpty) Text(note, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: Icon(Icons.circle, size: 12, color: _qualityColor(context)),
    );
  }
}

/// 序盤/中盤/終盤ごとの平均ロス・悪手数を表示する - 競合アプリの
/// 「局面別の強さ」表示に相当するが、実在の着手データのみから算出
/// する（[ReversiaGameAnalysis.phaseBreakdown]参照）。
class _PhaseBreakdownCard extends StatelessWidget {
  const _PhaseBreakdownCard({required this.breakdown});

  final Map<ReversiaGamePhase, ReversiaPhaseStats> breakdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gameReviewPhaseBreakdownTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final phase in ReversiaGamePhase.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _PhaseRow(phase: phase, stats: breakdown[phase]!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.phase, required this.stats});

  final ReversiaGamePhase phase;
  final ReversiaPhaseStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (stats.moveCount == 0) {
      return Row(
        children: [
          SizedBox(width: 48, child: Text(phase.label)),
          Expanded(child: Text(l10n.gameReviewNoMovesInPhaseMessage)),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 48, child: Text(phase.label)),
        Expanded(
          child: Text(
            l10n.gameReviewPhaseStatsLabel(
              stats.averageLoss.toStringAsFixed(0),
              stats.mistakeCount,
            ),
          ),
        ),
      ],
    );
  }
}
