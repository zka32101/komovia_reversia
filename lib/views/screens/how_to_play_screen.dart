import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 遊び方説明 - オンボーディングと違い、いつでも開けるルールリファレンス
/// （komovia_goの`HowToPlayScreen`と同じ役割・構成だが、reversiaには
/// l10n基盤が無いため文言を直接ハードコードし、ゲームの中身自体が
/// 全く違う - reversiaは囲碁の地合い/呼吸点ではなく、駒の表裏と移動、
/// オセロ的な色変え捕獲、キング捕獲で即終局する点が特徴）。対局中に
/// 「これどうだったっけ」となったときに参照できることを意図している。
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  List<_RuleSection> _sections(AppLocalizations l10n) => [
        _RuleSection(
          icon: Icons.sync_alt,
          title: l10n.howToPlayPieceSidesTitle,
          body: l10n.howToPlayPieceSidesBody,
        ),
        _RuleSection(
          icon: Icons.cached,
          title: l10n.howToPlayCaptureTitle,
          body: l10n.howToPlayCaptureBody,
        ),
        _RuleSection(
          icon: Icons.emoji_events_outlined,
          title: l10n.howToPlayKingTitle,
          body: l10n.howToPlayKingBody,
        ),
        _RuleSection(
          icon: Icons.block_outlined,
          title: l10n.howToPlayOtherEndConditionsTitle,
          body: l10n.howToPlayOtherEndConditionsBody,
        ),
        _RuleSection(
          icon: Icons.balance,
          title: l10n.howToPlayHandicapAndAiTitle,
          body: l10n.howToPlayHandicapAndAiBody,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = _sections(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.howToPlayTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _SectionCard(section: sections[index]),
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
