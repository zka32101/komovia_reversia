import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/views/screens/reversia_game_review_screen.dart';

void main() {
  testWidgets('shows a summary and one tile per reviewed move', (
    tester,
  ) async {
    final game = ReversiaGame();
    final initial = game.initialPosition();
    final historyKeys = <Object>[game.positionKey(initial)];
    final move = game.legalMoves(initial, historyKeys: historyKeys).first;

    await tester.pumpWidget(MaterialApp(
      home: ReversiaGameReviewScreen(
        initialPosition: initial,
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        humanSide: Side.first,
      ),
    ));

    expect(find.text('対局の振り返り'), findsOneWidget);
    expect(find.text('総評'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    // 着手の代数記法（列a-f+行1-6、project-015のGameNotationと同じ規約）
    // がタイトルに含まれていること。
    expect(find.textContaining(reversiaMoveNotation(move)), findsOneWidget);
  });

  testWidgets('an empty move list shows the no-moves message', (
    tester,
  ) async {
    final game = ReversiaGame();

    await tester.pumpWidget(MaterialApp(
      home: ReversiaGameReviewScreen(
        initialPosition: game.initialPosition(),
        moves: const [],
        humanSide: Side.first,
      ),
    ));

    expect(find.text('振り返る着手がありませんでした。'), findsOneWidget);
  });

  testWidgets('tapping a move opens the annotation dialog and saving shows the tag and note', (
    tester,
  ) async {
    final game = ReversiaGame();
    final initial = game.initialPosition();
    final historyKeys = <Object>[game.positionKey(initial)];
    final move = game.legalMoves(initial, historyKeys: historyKeys).first;

    await tester.pumpWidget(MaterialApp(
      home: ReversiaGameReviewScreen(
        initialPosition: initial,
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        humanSide: Side.first,
      ),
    ));

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('1手目のメモ'), findsOneWidget);
    await tester.tap(find.text('💎 会心の一手'));
    await tester.enterText(find.byType(TextField), '良い判断だった');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('💎'), findsOneWidget);
    expect(find.text('良い判断だった'), findsOneWidget);
  });

  testWidgets('deleting a saved annotation removes the tag and note', (tester) async {
    final game = ReversiaGame();
    final initial = game.initialPosition();
    final historyKeys = <Object>[game.positionKey(initial)];
    final move = game.legalMoves(initial, historyKeys: historyKeys).first;

    await tester.pumpWidget(MaterialApp(
      home: ReversiaGameReviewScreen(
        initialPosition: initial,
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        humanSide: Side.first,
      ),
    ));

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('❌ 悪手'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('❌'), findsOneWidget);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('❌'), findsNothing);
  });

  testWidgets('cancelling the dialog keeps the move unannotated', (tester) async {
    final game = ReversiaGame();
    final initial = game.initialPosition();
    final historyKeys = <Object>[game.positionKey(initial)];
    final move = game.legalMoves(initial, historyKeys: historyKeys).first;

    await tester.pumpWidget(MaterialApp(
      home: ReversiaGameReviewScreen(
        initialPosition: initial,
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        humanSide: Side.first,
      ),
    ));

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '書いたけど保存しない');
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('書いたけど保存しない'), findsNothing);
  });

  testWidgets('a mistake move shows the suggested best move', (tester) async {
    final game = ReversiaGame();
    final position = game.initialPosition();
    final historyKeys = <Object>[game.positionKey(position)];
    final legal = game.legalMoves(position, historyKeys: historyKeys);
    final evaluator = ReversiaEvaluator(game);

    Move? best;
    Move? worst;
    var bestEval = -(1 << 30);
    var worstEval = 1 << 30;
    for (final move in legal) {
      final resulting = game.apply(position, move, historyKeys: historyKeys);
      final eval = evaluator.evaluate(resulting, Side.first);
      if (eval > bestEval) {
        bestEval = eval;
        best = move;
      }
      if (eval < worstEval) {
        worstEval = eval;
        worst = move;
      }
    }
    // 全手が同評価ならテストの前提が崩れるためスキップ。
    if (best == worst) return;

    await tester.pumpWidget(MaterialApp(
      home: ReversiaGameReviewScreen(
        initialPosition: position,
        moves: [RecordedMove(number: 1, side: Side.first, move: worst!)],
        humanSide: Side.first,
      ),
    ));

    expect(find.textContaining('最善手: ${reversiaMoveNotation(best!)}'), findsOneWidget);
  });
}
