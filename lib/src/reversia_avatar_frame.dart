import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/reversia_game_stats.dart';

/// フレームのアンロック条件の種類。どれも`reversia_game_stats/{uid}`
/// （AI対局の勝敗・連勝記録）から導出できるものだけに限っている。
enum FrameRequirementKind { gamesPlayed, wins, longestWinStreak }

/// アバターフレーム1件 - `komovia_core`の共有`AvatarFrame`に、この
/// アプリ固有のアンロック条件と描画色を組み合わせたもの。フレームは
/// 課金では手に入らず、対局を重ねることでのみ獲得する（無料レイヤー）。
class ReversiaAvatarFrame {
  const ReversiaAvatarFrame({
    required this.frame,
    required this.kind,
    required this.threshold,
  });

  final AvatarFrame frame;
  final FrameRequirementKind kind;
  final int threshold;

  String get id => frame.id;

  bool isMetBy(ReversiaGameStats stats) {
    switch (kind) {
      case FrameRequirementKind.gamesPlayed:
        return stats.totalGames >= threshold;
      case FrameRequirementKind.wins:
        return stats.wins >= threshold;
      case FrameRequirementKind.longestWinStreak:
        return stats.longestWinStreak >= threshold;
    }
  }

  Color get color => tierColor(frame.tier);

  static Color tierColor(FrameTier tier) {
    switch (tier) {
      case FrameTier.bronze:
        return const Color(0xFFCD7F32);
      case FrameTier.silver:
        return const Color(0xFFC0C0C0);
      case FrameTier.gold:
        return const Color(0xFFFFC107);
      case FrameTier.platinum:
        return const Color(0xFF7FDBFF);
    }
  }

  static const all = <ReversiaAvatarFrame>[
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'first_game', name: 'はじめの一局', tier: FrameTier.bronze),
      kind: FrameRequirementKind.gamesPlayed,
      threshold: 1,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'first_win', name: '初勝利', tier: FrameTier.bronze),
      kind: FrameRequirementKind.wins,
      threshold: 1,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'games_10', name: '常連', tier: FrameTier.silver),
      kind: FrameRequirementKind.gamesPlayed,
      threshold: 10,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'wins_10', name: '勝ち慣れ', tier: FrameTier.silver),
      kind: FrameRequirementKind.wins,
      threshold: 10,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'streak_3', name: '三連勝', tier: FrameTier.gold),
      kind: FrameRequirementKind.longestWinStreak,
      threshold: 3,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'games_50', name: '盤上の住人', tier: FrameTier.gold),
      kind: FrameRequirementKind.gamesPlayed,
      threshold: 50,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'wins_50', name: '名手', tier: FrameTier.platinum),
      kind: FrameRequirementKind.wins,
      threshold: 50,
    ),
    ReversiaAvatarFrame(
      frame: AvatarFrame(id: 'streak_10', name: '十連勝', tier: FrameTier.platinum),
      kind: FrameRequirementKind.longestWinStreak,
      threshold: 10,
    ),
  ];

  /// 不明なidや`null`（フレームなし）は`null`を返す。
  static ReversiaAvatarFrame? byId(String? id) {
    if (id == null) return null;
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }

  static Set<String> unlockedIds(ReversiaGameStats stats) =>
      {for (final f in all) if (f.isMetBy(stats)) f.id};

  /// 保存済みの選択を実際に表示してよいフレームに解決する。カタログから
  /// 消えたidや、（統計がリセットされた等で）条件を満たさなくなった
  /// フレームはフレームなしにフォールバックする。
  static ReversiaAvatarFrame? resolveSelected(String? id, ReversiaGameStats stats) {
    final frame = byId(id);
    if (frame == null) return null;
    return AvatarFrame.isUnlocked(frame.id, unlockedIds(stats)) ? frame : null;
  }
}

/// アバター絵文字を、選択中フレームの色の円形ボーダー付きで描画する。
/// [frame]が`null`ならボーダー無し。
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({super.key, required this.emoji, this.frame, this.size = 40});

  final String emoji;
  final ReversiaAvatarFrame? frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    return Container(
      key: const ValueKey('framed-avatar'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: f == null ? null : Border.all(color: f.color, width: 3),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.6)),
    );
  }
}
