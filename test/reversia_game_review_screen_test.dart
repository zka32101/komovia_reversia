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
}
