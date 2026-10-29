/// プレイヤーアバター（絵文字ベース）。project-015の`avatars_provider.dart`
/// にはレアリティ・アンロック日時・フレーム/ボーダー等のコスメアイテムを
/// 持つガチャ的なシステムがあったが、実際にアンロックを発生させる仕組み
/// （対局実績との連動等）が存在せず、全アバターが実質いつでも選べる
/// だけだったため、ここでは「いつでも好きな絵文字を選べる」最小構成
/// として移植する - 固定の絵文字セットから選ぶだけで、課金・実績要素は
/// 無い。
class ReversiaAvatar {
  final String id;
  final String emoji;
  final String label;

  const ReversiaAvatar({required this.id, required this.emoji, required this.label});

  static const defaultAvatar = ReversiaAvatar(id: 'penguin', emoji: '🐧', label: 'ペンギン');

  static const all = <ReversiaAvatar>[
    defaultAvatar,
    ReversiaAvatar(id: 'bear', emoji: '🐻', label: 'クマ'),
    ReversiaAvatar(id: 'lion', emoji: '🦁', label: 'ライオン'),
    ReversiaAvatar(id: 'eagle', emoji: '🦅', label: 'イーグル'),
    ReversiaAvatar(id: 'fox', emoji: '🦊', label: 'フォックス'),
    ReversiaAvatar(id: 'star', emoji: '⭐', label: 'スター'),
    ReversiaAvatar(id: 'moon', emoji: '🌙', label: 'ムーン'),
    ReversiaAvatar(id: 'dragon', emoji: '🐉', label: 'ドラゴン'),
    ReversiaAvatar(id: 'phoenix', emoji: '🔥', label: 'フェニックス'),
    ReversiaAvatar(id: 'owl', emoji: '🦉', label: 'アウル'),
    ReversiaAvatar(id: 'turtle', emoji: '🐢', label: 'タートル'),
    ReversiaAvatar(id: 'octopus', emoji: '🐙', label: 'オクトパス'),
  ];

  static ReversiaAvatar byId(String? id) {
    if (id == null) return defaultAvatar;
    return all.firstWhere((a) => a.id == id, orElse: () => defaultAvatar);
  }
}
