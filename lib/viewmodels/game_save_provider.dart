import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/game_save_service.dart';

final gameSaveServiceProvider = Provider<GameSaveServiceLike>(
  (ref) => GameSaveService(),
);

/// `HomeScreen`が「続きから」タイルを出すかどうかの判定に使う。
final hasInProgressGameProvider = FutureProvider<bool>((ref) async {
  final saved = await ref.watch(gameSaveServiceProvider).loadInProgressGame();
  return saved != null && saved.isNotEmpty;
});
