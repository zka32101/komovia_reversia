import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../services/board_theme_preferences.dart';
import '../../src/reversia_cosmetics.dart';
import '../../viewmodels/purchase_provider.dart';
import 'paywall_screen.dart';

/// 盤スキン・駒スキンの着せ替え画面（設定画面から遷移）。無料スキンは
/// 誰でも選べ、サポーター向けスキンは既存のプレミアムサポーター権限
/// （[isPremiumProvider]）で解放される。未解放のスキンをタップすると
/// サポーター画面（[PaywallScreen]）への導線を出す。単品購入ボタンは
/// まだ無い（`reversia_cosmetics.dart`の先頭コメント参照）。
class CosmeticShopScreen extends ConsumerStatefulWidget {
  CosmeticShopScreen({super.key, this.uid, BoardThemePreferencesLike? preferences})
      : preferences = preferences ?? BoardThemePreferences();

  final String? uid;
  final BoardThemePreferencesLike preferences;

  @override
  ConsumerState<CosmeticShopScreen> createState() => _CosmeticShopScreenState();
}

class _CosmeticShopScreenState extends ConsumerState<CosmeticShopScreen> {
  String? _boardId;
  String? _discId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final board = await widget.preferences.getBoardSkinId();
    final disc = await widget.preferences.getDiscSkinId();
    if (!mounted) return;
    setState(() {
      _boardId = board;
      _discId = disc;
    });
  }

  void _showLocked(AppLocalizations l10n) {
    final uid = widget.uid;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.cosmeticLockedMessage),
        action: uid == null
            ? null
            : SnackBarAction(
                label: l10n.cosmeticBecomeSupporter,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaywallScreen(uid: uid)),
                ),
              ),
      ),
    );
  }

  Widget _tile({
    required AppLocalizations l10n,
    required CosmeticItem item,
    required Widget preview,
    required bool selected,
    required bool owned,
    required VoidCallback onSelect,
  }) {
    return ListTile(
      key: ValueKey('cosmetic-${item.category}-${item.id}'),
      leading: preview,
      title: Text(item.name),
      subtitle: Text(item.isFreeForAll ? l10n.cosmeticFreeLabel : l10n.cosmeticSupporterLabel),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Colors.teal)
          : owned
              ? null
              : const Icon(Icons.lock_outline),
      onTap: owned ? onSelect : () => _showLocked(l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = ref.watch(isPremiumProvider);
    final loaded = _boardId != null && _discId != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cosmeticShopTitle)),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(title: Text(l10n.cosmeticBoardSkinsHeader)),
                for (final skin in ReversiaCosmetics.boardSkins)
                  _tile(
                    l10n: l10n,
                    item: skin.item,
                    preview: _BoardPreview(skin: skin),
                    selected: skin.id == _boardId,
                    owned: ReversiaCosmetics.isOwned(skin.item, hasActiveSubscription: premium),
                    onSelect: () {
                      setState(() => _boardId = skin.id);
                      widget.preferences.setBoardSkinId(skin.id);
                    },
                  ),
                const Divider(),
                ListTile(title: Text(l10n.cosmeticDiscSkinsHeader)),
                for (final skin in ReversiaCosmetics.discSkins)
                  _tile(
                    l10n: l10n,
                    item: skin.item,
                    preview: _DiscPreview(skin: skin),
                    selected: skin.id == _discId,
                    owned: ReversiaCosmetics.isOwned(skin.item, hasActiveSubscription: premium),
                    onSelect: () {
                      setState(() => _discId = skin.id);
                      widget.preferences.setDiscSkinId(skin.id);
                    },
                  ),
              ],
            ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.skin});
  final ReversiaBoardSkin skin;

  @override
  Widget build(BuildContext context) {
    Widget cell(Color c) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: c,
            border: skin.gridLineColor == null ? null : Border.all(color: skin.gridLineColor!, width: 1),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [cell(skin.darkSquare), cell(skin.lightSquare)]),
        Row(mainAxisSize: MainAxisSize.min, children: [cell(skin.lightSquare), cell(skin.darkSquare)]),
      ],
    );
  }
}

class _DiscPreview extends StatelessWidget {
  const _DiscPreview({required this.skin});
  final ReversiaDiscSkin skin;

  @override
  Widget build(BuildContext context) {
    Widget disc(Color c) => Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
            gradient: skin.gloss
                ? RadialGradient(
                    center: const Alignment(-0.4, -0.4),
                    colors: [Color.lerp(c, Colors.white, 0.6)!, c],
                  )
                : null,
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [disc(skin.frontColor), disc(skin.backColor)]);
  }
}
