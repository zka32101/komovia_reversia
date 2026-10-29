import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/views/screens/how_to_play_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HowToPlayScreen()),
    );
    await tester.pump();
  }

  testWidgets('shows all rule section titles collapsed by default', (tester) async {
    await pumpScreen(tester);

    expect(find.text('駒の表と裏'), findsOneWidget);
    expect(find.text('捕獲（オセロ的な色変え）'), findsOneWidget);
    expect(find.text('キングと勝敗'), findsOneWidget);
    expect(find.text('その他の終局条件'), findsOneWidget);
    expect(find.text('ハンディキャップとAIの強さ'), findsOneWidget);

    // 本文は折りたたまれているので表示されていない。
    expect(find.textContaining('上下左右に1マスだけ動けます'), findsNothing);
  });

  testWidgets('tapping a section expands it to show its body text', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('駒の表と裏'));
    await tester.pumpAndSettle();

    expect(find.textContaining('上下左右に1マスだけ動けます'), findsOneWidget);
  });
}
