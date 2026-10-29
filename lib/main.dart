import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_reversia/komovia_reversia.dart';

import 'firebase_options.dart';
import 'services/board_theme_preferences.dart';
import 'services/game_save_service.dart';
import 'services/onboarding_service.dart';
import 'utils/reversia_move_feedback.dart';
import 'viewmodels/index.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/leaderboard_screen.dart';
import 'views/screens/notification_screen.dart';
import 'views/screens/onboarding_screen.dart';
import 'views/screens/puzzle_screen.dart';
import 'views/screens/reversia_game_review_screen.dart';
import 'views/screens/reversia_matching_screen.dart';

/// komovia_reversia's app shell: a single local human-vs-AI game screen
/// exercising `ReversiaGame`/`ReversiaEngine`/`ReversiaBoardRenderer` end
/// to end, following the priority order in the package README ("app
/// shell first, then onboarding, then daily-puzzle UI, then Firebase
/// social wiring" — see also `komovia_shogi`'s `main.dart` as the
/// pattern this mirrors).
///
/// Firebase/Riverpod are now wired in (this is the "Firebase social
/// wiring" step from that priority order), with placeholder config
/// (`firebase_options.dart`) until `flutterfire configure` is run against
/// a real project — the point of this step is only to lay the same
/// foundation komovia_shogi/komovia_go already had before their PvP
/// features were built; no social/PvP screens exist yet.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Route uncaught errors to Crashlytics so production crashes are
    // visible instead of silently dropped (komovia_go's main.dart, same
    // wiring). Only set up once Firebase has actually initialized —
    // against the current placeholder config this never runs, same as
    // every other Firebase-backed feature in this app.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Placeholder Firebase config won't actually initialize against a real
    // backend; swallow so the app still runs standalone.
  }
  runApp(const ProviderScope(child: KomoviaReversiaApp()));
}

class KomoviaReversiaApp extends StatelessWidget {
  const KomoviaReversiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Komovia Reversia',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const _RootScreen(),
    );
  }
}

/// 初回起動時だけ`OnboardingScreen`を表示し、完了済み（または完了直後）
/// なら`ReversiaGameScreen`へ進む — komovia_shogiの`_RootScreen`と同じ
/// 役割。サインイン（匿名）はバックグラウンドで行い、オンボーディング・
/// 対局自体はその完了を待たない（将来の社交/PvP機能が必要になった時点で
/// uidを使えばよい）。
class _RootScreen extends ConsumerStatefulWidget {
  const _RootScreen();

  @override
  ConsumerState<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<_RootScreen> {
  final _onboardingService = OnboardingService();
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
    _onboardingService.hasCompletedOnboarding().then((completed) {
      if (mounted) setState(() => _hasCompletedOnboarding = completed);
    });
  }

  Future<void> _ensureSignedIn() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await ref.read(authServiceProvider).signInAnonymously();
      }
    } catch (_) {
      // No real Firebase project configured yet.
    }
  }

  void _onOnboardingFinished() {
    setState(() => _hasCompletedOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    // ストアに未確認応答のまま残っている購入を、割り込みが起きない
    // アプリ起動のたびに回収できるよう、ホーム画面に進む前の全状態で
    // watchしておく（GoEnの`purchaseRecoveryProvider`と同じ役割）。
    ref.watch(purchaseRecoveryProvider);

    final completed = _hasCompletedOnboarding;
    if (completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!completed) {
      return OnboardingScreen(onFinished: _onOnboardingFinished);
    }
    return HomeScreen(
      onPlayReversia: ({bool resume = false}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReversiaGameScreen(resume: resume)),
      ),
    );
  }
}

/// A single local game: the player is always [Side.first] (前row,
/// matching `ReversiaGame.initialPosition`'s placement), the AI always
/// [Side.second]. Tap a piece to select it (legal destinations
/// highlight), tap a destination to move; the AI replies automatically
/// after a short delay once the position is its turn.
class ReversiaGameScreen extends ConsumerStatefulWidget {
  const ReversiaGameScreen({
    super.key,
    this.resume = false,
    GameSaveServiceLike? saveService,
    BoardThemePreferencesLike? themePreferences,
  })  : saveService = saveService ?? const _NewGameSaveService(),
        themePreferences = themePreferences ?? const _NewBoardThemePreferences();

  /// trueなら、`GameSaveService`に保存された進行中の対局（あれば）を
  /// 初期局面から着手を再生して復元する。falseなら常に新規対局から
  /// 始める（既存の挙動そのまま）。
  final bool resume;
  final GameSaveServiceLike saveService;
  final BoardThemePreferencesLike themePreferences;

  @override
  ConsumerState<ReversiaGameScreen> createState() =>
      _ReversiaGameScreenState();
}

/// `_NewGameSaveService`と同じ役割（constコンストラクタのデフォルト
/// 引数用の薄いラッパー）。
class _NewBoardThemePreferences implements BoardThemePreferencesLike {
  const _NewBoardThemePreferences();

  @override
  Future<ReversiaBoardTheme> getTheme() => BoardThemePreferences().getTheme();

  @override
  Future<void> setTheme(ReversiaBoardTheme theme) =>
      BoardThemePreferences().setTheme(theme);
}

/// `const`コンストラクタのデフォルト引数で使うための薄いラッパー -
/// `GameSaveService()`自体は非const（SharedPreferencesの実プラグインを
/// 内部で呼ぶだけで、コンストラクタ自体はconstにできる特別な理由は無い
/// が、`ReversiaGameScreen`のデフォルトコンストラクタをconstのまま保てる
/// よう、同じ役割を持つconstなラッパーを介す）。
class _NewGameSaveService implements GameSaveServiceLike {
  const _NewGameSaveService();

  @override
  Future<String?> loadInProgressGame() => GameSaveService().loadInProgressGame();

  @override
  Future<void> saveInProgressGame(String movesRecord) =>
      GameSaveService().saveInProgressGame(movesRecord);

  @override
  Future<void> clearInProgressGame() => GameSaveService().clearInProgressGame();
}

class _ReversiaGameScreenState extends ConsumerState<ReversiaGameScreen> {
  /// `ReversiaEngine.bestMove`は既にlevel引数を受け取っていたが、変更
  /// できるUIがどこにも無かった（project-015からの移植漏れ - 競合
  /// Othello/Reversiアプリの多くが標準機能として持つAI強さ選択）。
  /// AIの強さは今後の着手にのみ影響するため、ハンディキャップと違って
  /// 変更時に新規対局を始め直す必要は無い。
  int _aiLevel = 2;

  final _game = ReversiaGame();
  final _engine = ReversiaEngine();
  var _renderer = ReversiaBoardRenderer();

  /// 選択中のハンディキャップ（無しならnull）。`ReversiaHandicapRule`自体は
  /// komovia_coreの`HandicapRule`インターフェースを実装済みだったが、
  /// どの画面からも呼ばれていなかった（project-015からの移植漏れ）。
  ReversiaHandicapRule? _handicap;

  ReversiaPosition get _freshInitialPosition {
    final standard = _game.initialPosition();
    return _handicap?.apply(standard) ?? standard;
  }

  // `late`な初期化子（`= _freshInitialPosition`等）にすると、最初に
  // "読まれた"タイミングで遅延評価されるため、`_initialPosition`が
  // `_openReview`/`_undo`まで一度も読まれなければ、その時点で既に何手も
  // 進んだ`_position`の現在値を誤って捕捉してしまう（実際に発生していた
  // バグ - `_undo`追加時に発見）。そのため値自体は`initState`で明示的に
  // 代入し、どの手が着手される前に必ず正しい初期局面を捕捉する。
  late ReversiaPosition _position;
  late ReversiaPosition _initialPosition;
  final List<Object> _historyKeys = [];
  final List<RecordedMove> _moveRecord = [];
  Square? _selected;
  List<Square> _hints = const [];
  Move? _lastMove;
  bool _aiThinking = false;
  Timer? _aiMoveTimer;

  GameResult get _result =>
      _game.result(_position, historyKeys: _historyKeys);

  @override
  void initState() {
    super.initState();
    _initialPosition = _freshInitialPosition;
    _position = _initialPosition;
    _historyKeys.add(_game.positionKey(_position));
    if (widget.resume) _loadSavedGame();
    _loadBoardTheme();
  }

  /// 保存済みの配色テーマ（あれば）を読み込んで反映する。無ければ既定の
  /// `ReversiaBoardTheme.classic`のまま（`ReversiaBoardRenderer()`の
  /// デフォルト値と同じ）。
  Future<void> _loadBoardTheme() async {
    final theme = await widget.themePreferences.getTheme();
    if (!mounted) return;
    setState(() => _renderer = ReversiaBoardRenderer(theme: theme));
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    super.dispose();
  }

  /// 保存済みの着手レコードを初期局面から再生して局面・履歴・AIの番を
  /// 復元する。保存が無い、または壊れている場合は何もしない（新規対局の
  /// まま進める）。
  Future<void> _loadSavedGame() async {
    final saved = await widget.saveService.loadInProgressGame();
    if (saved == null || saved.isEmpty || !mounted) return;

    try {
      final record = _game.importRecord(saved);
      var position = _game.initialPosition();
      final historyKeys = [_game.positionKey(position)];
      Move? lastMove;
      for (final m in record.moves) {
        position = _game.apply(position, m.move, historyKeys: historyKeys);
        historyKeys.add(_game.positionKey(position));
        lastMove = m.move;
      }
      if (!mounted) return;
      setState(() {
        _position = position;
        _historyKeys
          ..clear()
          ..addAll(historyKeys);
        _moveRecord
          ..clear()
          ..addAll(record.moves);
        _lastMove = lastMove;
      });
      _maybeScheduleAiMove();
    } catch (_) {
      // 壊れた保存データは捨てて新規対局のまま進める。
      await widget.saveService.clearInProgressGame();
    }
  }

  void _newGame() {
    _aiMoveTimer?.cancel();
    widget.saveService.clearInProgressGame();
    setState(() {
      _position = _freshInitialPosition;
      _initialPosition = _position;
      _historyKeys.clear();
      _historyKeys.add(_game.positionKey(_position));
      _moveRecord.clear();
      _selected = null;
      _hints = const [];
      _lastMove = null;
      _aiThinking = false;
    });
  }

  void _applyMove(Move move) {
    final mover = _position.sideToMove;
    final target = move is BoardMove ? _position.at(move.to) : null;
    if (target != null && target.owner != mover) {
      playReversiaCaptureFeedback();
    } else {
      playReversiaMovePlaceFeedback();
    }
    setState(() {
      _moveRecord.add(RecordedMove(
        number: _moveRecord.length + 1,
        side: mover,
        move: move,
      ));
      _position = _game.apply(_position, move, historyKeys: _historyKeys);
      _historyKeys.add(_game.positionKey(_position));
      _lastMove = move;
      _selected = null;
      _hints = const [];
    });
    final result = _result;
    if (!result.isOngoing) {
      ref.read(updateReversiaRatingAfterGameProvider)(result, _aiLevel);
      widget.saveService.clearInProgressGame();
    } else if (_handicap == null) {
      // ハンディキャップ対局は`_freshInitialPosition`（標準局面ではない）
      // から再生する必要があるが、保存データは常に標準局面からの再生を
      // 前提にしている（`_loadSavedGame`参照）ため、ハンディキャップ対局
      // は保存しない - 再開不可の対局として割り切る。
      widget.saveService.saveInProgressGame(
        _game.exportRecord(
          GameRecord(gameId: 'local', moves: _moveRecord, result: result),
        ),
      );
    }
    _maybeScheduleAiMove();
  }

  /// 直前の自分の着手を取り消す。AIがすでに応手していれば、その応手と
  /// 自分の着手の両方を取り消して再び自分の番に戻す（競合アプリの多くが
  /// 標準機能として持つ「待った」 - strict alternation前提のこのゲーム
  /// では、取り消す着手数は末尾がAI側かどうかで1手か2手かのいずれか）。
  /// 対局終了後でも呼べる（最後の一手を取り消して対局を続行できる）。
  void _undo() {
    if (_moveRecord.isEmpty) return;
    _aiMoveTimer?.cancel();

    final toRemove = _moveRecord.last.side == Side.second ? 2 : 1;
    final remaining =
        (_moveRecord.length - toRemove).clamp(0, _moveRecord.length);
    final newRecord = _moveRecord.sublist(0, remaining);

    var position = _initialPosition;
    final historyKeys = [_game.positionKey(position)];
    Move? lastMove;
    for (final m in newRecord) {
      position = _game.apply(position, m.move, historyKeys: historyKeys);
      historyKeys.add(_game.positionKey(position));
      lastMove = m.move;
    }

    setState(() {
      _position = position;
      _historyKeys
        ..clear()
        ..addAll(historyKeys);
      _moveRecord
        ..clear()
        ..addAll(newRecord);
      _selected = null;
      _hints = const [];
      _lastMove = lastMove;
      _aiThinking = false;
    });

    if (_handicap == null) {
      // ハンディキャップ対局は保存しない方針（_applyMove参照）と同じ。
      if (_moveRecord.isEmpty) {
        widget.saveService.clearInProgressGame();
      } else {
        widget.saveService.saveInProgressGame(
          _game.exportRecord(
            GameRecord(gameId: 'local', moves: _moveRecord, result: _result),
          ),
        );
      }
    }
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReversiaGameReviewScreen(
          initialPosition: _initialPosition,
          moves: List.of(_moveRecord),
          humanSide: Side.first,
        ),
      ),
    );
  }

  /// 競合アプリの多くが標準機能として持つヒント — `ReversiaEvaluator`
  /// （AI探索・振り返り機能と同じ評価関数）で現局面の最善手を1つ求め、
  /// 通常のタップ選択と同じ`_selected`/`_hints`でハイライトする（自動で
  /// は着手しない。着手するかどうかは依然プレイヤー自身が選ぶ）。
  void _showHint() {
    if (_aiThinking || !_result.isOngoing) return;
    if (_position.sideToMove != Side.first) return;

    final best = bestLegalMove(
      _game,
      ReversiaEvaluator(_game),
      _position,
      Side.first,
      historyKeys: _historyKeys,
    );
    if (best == null) return;

    setState(() {
      _selected = best.from;
      _hints = [best.to];
    });
  }

  void _maybeScheduleAiMove() {
    if (!_result.isOngoing) return;
    if (_position.sideToMove != Side.second) return;
    setState(() => _aiThinking = true);
    _aiMoveTimer = Timer(const Duration(milliseconds: 400), () async {
      final move = await _engine.bestMove(_position, level: _aiLevel);
      if (!mounted) return;
      setState(() => _aiThinking = false);
      if (move != null) _applyMove(move);
    });
  }

  void _onTapSquare(Square square) {
    if (_aiThinking || !_result.isOngoing) return;
    if (_position.sideToMove != Side.first) return;

    if (_selected != null && _hints.contains(square)) {
      _applyMove(BoardMove(from: _selected!, to: square));
      return;
    }

    final piece = _position.at(square);
    if (piece != null && piece.owner == Side.first) {
      final legal = _game
          .legalMoves(_position, historyKeys: _historyKeys)
          .whereType<BoardMove>()
          .where((m) => m.from == square)
          .toList();
      setState(() {
        _selected = square;
        _hints = legal.map((m) => m.to).toList();
      });
    } else {
      setState(() {
        _selected = null;
        _hints = const [];
      });
    }
  }

  /// ハンディキャップを選び直す（常に新規対局として始め直す - 対局中に
  /// 内容を変えると現在の局面と矛盾するため）。
  Future<void> _pickHandicap() async {
    final selected = await showDialog<ReversiaHandicapRule?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('ハンディキャップ'),
        children: [
          RadioListTile<ReversiaHandicapRule?>(
            title: const Text('なし'),
            value: null,
            groupValue: _handicap,
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
          for (final rule in ReversiaHandicapRule.all)
            RadioListTile<ReversiaHandicapRule?>(
              title: Text(rule.label),
              value: rule,
              groupValue: _handicap,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _handicap = selected);
    _newGame();
  }

  static const _aiLevelLabels = {1: '初級', 2: '中級', 3: '上級'};

  /// AIの強さを選び直す。ハンディキャップと違い、今後の着手にのみ影響
  /// するため新規対局として始め直す必要は無い（対局中に変更しても
  /// 現在の局面・着手履歴と矛盾しない）。
  Future<void> _pickAiLevel() async {
    final selected = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('AIの強さ'),
        children: [
          for (final level in _aiLevelLabels.keys)
            RadioListTile<int>(
              title: Text(_aiLevelLabels[level]!),
              value: level,
              groupValue: _aiLevel,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _aiLevel = selected);
  }

  /// 盤・駒の配色テーマを選び直す。局面には影響しないため新規対局として
  /// 始め直す必要は無い（AIの強さと同じ考え方）。
  Future<void> _pickBoardTheme() async {
    final selected = await showDialog<ReversiaBoardTheme>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('盤の配色'),
        children: [
          for (final theme in ReversiaBoardTheme.all)
            RadioListTile<ReversiaBoardTheme>(
              title: Text(theme.label),
              secondary: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorSwatch(color: theme.lightSquare),
                  _ColorSwatch(color: theme.darkSquare),
                ],
              ),
              value: theme,
              groupValue: _renderer.theme,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _renderer = ReversiaBoardRenderer(theme: selected));
    widget.themePreferences.setTheme(selected);
  }

  String get _statusText {
    final result = _result;
    if (result.isOngoing) {
      if (_aiThinking) return 'AIが考えています…';
      return _position.sideToMove == Side.first ? 'あなたの番です' : '相手の番です';
    }
    if (result.kind == ResultKind.draw) return '引き分けです';
    final youWon = result.winner == Side.first;
    return youWon ? 'あなたの勝ちです！' : 'あなたの負けです';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komovia Reversia'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final uid = ref.watch(currentUidProvider);
              if (uid == null) return const SizedBox.shrink();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: '通知',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationScreen(uid: uid),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final count = ref.watch(unreadNotificationCountProvider(uid));
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 6,
                        top: 6,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.red,
                          child: Text(
                            '$count',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final uid = ref.watch(currentUidProvider);
              return IconButton(
                icon: const Icon(Icons.group),
                tooltip: '対局相手を探す',
                onPressed: uid == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReversiaMatchingScreen(
                              uid: uid,
                              displayName: 'Player ${uid.substring(0, 6)}',
                            ),
                          ),
                        ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'ヒント',
            onPressed:
                (_result.isOngoing && !_aiThinking && _position.sideToMove == Side.first)
                    ? _showHint
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '待った',
            onPressed: _moveRecord.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'ランキング',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '今日の1局',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PuzzleScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AIの強さ',
            onPressed: _pickAiLevel,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: '盤の配色',
            onPressed: _pickBoardTheme,
          ),
          IconButton(
            icon: const Icon(Icons.balance),
            tooltip: 'ハンディキャップ',
            onPressed: _pickHandicap,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '新しい対局',
            onPressed: _newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_statusText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.maxWidth.clamp(0, 400).toDouble();
                    return GestureDetector(
                      key: const Key('reversia_board_gesture_detector'),
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
                          lastMove: _lastMove,
                          hints: _hints,
                          selected: _selected,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_result.isOngoing) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton(
                    onPressed: _newGame,
                    child: const Text('もう一度'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _moveRecord.isEmpty ? null : _openReview,
                    child: const Text('対局を振り返る'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `_pickBoardTheme`のダイアログで各テーマの明/暗マス色を小さく示す
/// プレビュー用の四角。
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}
