# komovia_reversia

Reversia（zka32101/project-015）のルール・盤表現・棋譜のKomovia移植。`komovia_core`の`Game`インターフェースを実装する。

Reversiaは「オセロ」ではなく、6×6マスで駒に表/裏の向きがあるオリジナルルール: 表向きは直交1マス移動、裏向きは対角2マスジャンプ。相手の駒がいる場所へ移動すると、その駒を奪って自分の色に変える（石を裏返す点だけオセロ的）。キング駒を奪うと即勝利。61手で終局した場合は駒数で判定、同数は引き分け。同一局面3回で反則負け。

依存の向き: komovia_shogi等と同じく、本パッケージ → `komovia_core`。Flutter/Firebase依存はまだない（段階1: ルール部分のみ）。UI・AI・オンライン対戦等の移植は次の段階。

## 現在の段階

段階1（`Game<ReversiaPosition>`実装 + `komovia_core/testkit.dart`契約テストのパス）。元の実装(project-015)との差分:

- `ResignMove`はproject-015の元エンジンには存在しなかったが、komovia_coreの`Game`契約が要求するため追加した。
- 合法手がない側の負け（元実装では`GameState.declareNoMovesLoss()`を呼び出し側が明示的に呼ぶ必要があった）は、`result()`内で自動的に判定するようにした。
- `WinReason`は既存の語彙を転用している: キング捕獲は`checkmate`、合法手なしの負けは`stalemate`（チェスの意味とは逆で、引き分けではなく負けを表す）、61手規定による駒数判定は`score`。

## 開発

```
dart pub get
dart analyze
dart test
```

## 参考

- `zka32101/project-015`（移行元: `lib/engine/board.dart`, `move_generator.dart`, `models.dart`, `game_state.dart`）
- `zka32101/komovia_core`（共通基盤）
- `zka32101/komovia_shogi`（移植パターンの参考実装）
