import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

/// 対局後の振り返り画面。競合アプリの「棋譜解析」「敗因分析」機能に
/// 相当 — [ReversiaGameAnalyzer]（評価関数ベースの決定的なローカル解析、
/// LLMは使わない）で[humanSide]の全着手を最善手と比較し、一手ごとの
/// 評価と総評を表示する。
class ReversiaGameReviewScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final analysis = ReversiaGameAnalyzer().analyze(
      initialPosition: initialPosition,
      moves: moves,
      side: humanSide,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('対局の振り返り')),
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
                    '総評',
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
          if (analysis.moveReviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('振り返る着手がありませんでした。'),
            )
          else
            ...analysis.moveReviews.map((review) => _MoveReviewTile(review)),
        ],
      ),
    );
  }
}

class _MoveReviewTile extends StatelessWidget {
  const _MoveReviewTile(this.review);

  final ReversiaMoveReview review;

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
    return ListTile(
      leading: CircleAvatar(child: Text('${review.moveNumber}')),
      title: Text(review.quality.label),
      subtitle: review.lossVsBest > 0
          ? Text('最善手との差: ${review.lossVsBest}点')
          : null,
      trailing: Icon(Icons.circle, size: 12, color: _qualityColor(context)),
    );
  }
}
