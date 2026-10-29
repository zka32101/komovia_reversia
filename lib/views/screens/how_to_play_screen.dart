import 'package:flutter/material.dart';

/// 遊び方説明 - オンボーディングと違い、いつでも開けるルールリファレンス
/// （komovia_goの`HowToPlayScreen`と同じ役割・構成だが、reversiaには
/// l10n基盤が無いため文言を直接ハードコードし、ゲームの中身自体が
/// 全く違う - reversiaは囲碁の地合い/呼吸点ではなく、駒の表裏と移動、
/// オセロ的な色変え捕獲、キング捕獲で即終局する点が特徴）。対局中に
/// 「これどうだったっけ」となったときに参照できることを意図している。
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _sections = [
    _RuleSection(
      icon: Icons.sync_alt,
      title: '駒の表と裏',
      body: 'すべての駒（キング以外）には表と裏があり、動くたびに表裏が'
          '入れ替わります。表向きの駒は上下左右に1マスだけ動けます。'
          '裏向きの駒は斜めに2マス（間のマスが空いていれば）ジャンプ'
          'できます。盤面の駒の色だけでなく、表裏の向きも着手の選択肢に'
          '影響するので、よく見て動かしましょう。',
    ),
    _RuleSection(
      icon: Icons.cached,
      title: '捕獲（オセロ的な色変え）',
      body: '相手の駒がいるマスへ移動すると、その駒を奪います。ただし'
          'チェスのように自分の駒がそのマスへ乗るのではなく、相手の駒'
          'そのものが自分の色に変わり、表裏も反転します（移動してきた'
          '自分の駒自体は消えます）。石を裏返すオセロの発想を、駒の移動'
          'ゲームに組み込んだのがReversiaの特徴です。',
    ),
    _RuleSection(
      icon: Icons.emoji_events_outlined,
      title: 'キングと勝敗',
      body: '両陣営に1枚ずつキングがいます。キングは上下左右斜めの8方向'
          'に1マス動け、他の駒と違って表裏はありません。相手のキングが'
          'いるマスへ移動すると、キングを奪ってその場に自分の駒が乗り、'
          '即座に勝利します。',
    ),
    _RuleSection(
      icon: Icons.block_outlined,
      title: 'その他の終局条件',
      body: '自分の番で動かせる駒が1つも無い場合、その時点で負けになり'
          'ます（チェスのステイルメイトと違い、Reversiaでは引き分けに'
          'なりません）。同じ局面が繰り返し現れた場合は、その繰り返しを'
          '発生させた側の負けです。長引いた対局は手数の上限に達すると、'
          'その時点で盤上の駒数が多い側の勝ち（同数なら引き分け）になり'
          'ます。',
    ),
    _RuleSection(
      icon: Icons.balance,
      title: 'ハンディキャップとAIの強さ',
      body: '対局画面のAppBarから、AIの強さ（初級/中級/上級）と'
          'ハンディキャップ（後手の駒を何枚か外して先手を有利にする）'
          'を選べます。ハンディキャップを変更すると対局は新規に始め'
          '直されますが、AIの強さはいつでも変更でき、現在の対局に'
          'そのまま反映されます。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('遊び方')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _SectionCard(section: _sections[index]),
      ),
    );
  }
}

class _RuleSection {
  final IconData icon;
  final String title;
  final String body;

  const _RuleSection({required this.icon, required this.title, required this.body});
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final _RuleSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(section.icon),
        title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(section.body, style: const TextStyle(height: 1.7)),
            ),
          ),
        ],
      ),
    );
  }
}
