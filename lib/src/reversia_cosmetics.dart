import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import 'reversia_board_theme.dart';

/// コスメティック（盤スキン・駒スキン）のカタログ。komovia_coreの共有型
/// [CosmeticItem]で「誰が使えるか」を表し、実際の色はこのファイルの
/// [ReversiaBoardSkin]/[ReversiaDiscSkin]が持つ。
///
/// 課金モデル: 無料スキンは全員が使える。プレミアムスキンは既存の
/// プレミアムサポーター権限（`premium_entitlements/{uid}`、
/// `isPremiumProvider`）に含まれる（`includedWithSubscription: true`）。
/// スキン単品の買い切り（`iapProductId`）はまだストア側にプロダクトが
/// 無いため設定していない - 追加する場合はここに`iapProductId`を入れ、
/// `PurchaseService`に単品購入フローを足す。
const String boardSkinCategory = 'boardSkin';
const String discSkinCategory = 'discSkin';

class ReversiaBoardSkin {
  const ReversiaBoardSkin({
    required this.item,
    required this.lightSquare,
    required this.darkSquare,
    this.gridLineColor,
  });

  final CosmeticItem item;
  final Color lightSquare;
  final Color darkSquare;
  final Color? gridLineColor;

  String get id => item.id;
}

class ReversiaDiscSkin {
  const ReversiaDiscSkin({
    required this.item,
    required this.frontColor,
    required this.backColor,
    this.gloss = false,
  });

  final CosmeticItem item;
  final Color frontColor;
  final Color backColor;
  final bool gloss;

  String get id => item.id;
}

class ReversiaCosmetics {
  ReversiaCosmetics._();

  static ReversiaBoardSkin _boardFromTheme(ReversiaBoardTheme t) => ReversiaBoardSkin(
        item: CosmeticItem(id: t.id, category: boardSkinCategory, name: t.label),
        lightSquare: t.lightSquare,
        darkSquare: t.darkSquare,
      );

  static ReversiaDiscSkin _discFromTheme(ReversiaBoardTheme t) => ReversiaDiscSkin(
        item: CosmeticItem(id: t.id, category: discSkinCategory, name: t.label),
        frontColor: t.frontPieceColor,
        backColor: t.backPieceColor,
      );

  /// 無料の盤スキンは既存の配色テーマ（木目/墨/翡翠）と同じidを使う
  /// （既存の`BoardThemePreferences`の保存値とそのまま互換）。
  static final List<ReversiaBoardSkin> boardSkins = [
    for (final t in ReversiaBoardTheme.all) _boardFromTheme(t),
    const ReversiaBoardSkin(
      item: CosmeticItem(
        id: 'marble',
        category: boardSkinCategory,
        name: '大理石',
        includedWithSubscription: true,
      ),
      lightSquare: Color(0xFFEDEBE6),
      darkSquare: Color(0xFFBDB8AE),
      gridLineColor: Color(0x33000000),
    ),
    const ReversiaBoardSkin(
      item: CosmeticItem(
        id: 'neon',
        category: boardSkinCategory,
        name: 'ネオン',
        includedWithSubscription: true,
      ),
      lightSquare: Color(0xFF141428),
      darkSquare: Color(0xFF0B0B1A),
      gridLineColor: Color(0xFF00E5FF),
    ),
    const ReversiaBoardSkin(
      item: CosmeticItem(
        id: 'kurogaki',
        category: boardSkinCategory,
        name: '黒柿',
        includedWithSubscription: true,
      ),
      lightSquare: Color(0xFF8B5A2B),
      darkSquare: Color(0xFF5C3A1E),
      gridLineColor: Color(0x55000000),
    ),
  ];

  static final List<ReversiaDiscSkin> discSkins = [
    for (final t in ReversiaBoardTheme.all) _discFromTheme(t),
    const ReversiaDiscSkin(
      item: CosmeticItem(
        id: 'glass',
        category: discSkinCategory,
        name: 'ガラス',
        includedWithSubscription: true,
      ),
      frontColor: Color(0xFF1C2541),
      backColor: Color(0xFFE0F7FA),
      gloss: true,
    ),
    const ReversiaDiscSkin(
      item: CosmeticItem(
        id: 'ruby_sapphire',
        category: discSkinCategory,
        name: '紅玉と青玉',
        includedWithSubscription: true,
      ),
      frontColor: Color(0xFF1565C0),
      backColor: Color(0xFFC62828),
      gloss: true,
    ),
    const ReversiaDiscSkin(
      item: CosmeticItem(
        id: 'gold_silver',
        category: discSkinCategory,
        name: '金と銀',
        includedWithSubscription: true,
      ),
      frontColor: Color(0xFFB0BEC5),
      backColor: Color(0xFFD4AF37),
      gloss: true,
    ),
  ];

  static ReversiaBoardSkin boardSkinById(String? id) =>
      boardSkins.firstWhere((s) => s.id == id, orElse: () => boardSkins.first);

  static ReversiaDiscSkin discSkinById(String? id) =>
      discSkins.firstWhere((s) => s.id == id, orElse: () => discSkins.first);

  static bool isOwned(CosmeticItem item, {required bool hasActiveSubscription}) =>
      item.isOwnedBy(
        hasActiveSubscription: hasActiveSubscription,
        // 単品購入はまだ無い（ファイル先頭のコメント参照）。
        purchasedProductIds: const {},
      );

  /// 選択中のスキンidから実際に描画するテーマを組み立てる。所有して
  /// いない（例: サポーター期限切れ）スキンは既定（木目）に戻す。
  /// 盤と駒が同じ既存テーマidなら既存の`ReversiaBoardTheme`定数を
  /// そのまま返すので、従来の見た目・保存値と完全に互換。
  static ReversiaBoardTheme resolveTheme({
    required String? boardSkinId,
    required String? discSkinId,
    required bool hasActiveSubscription,
  }) {
    var board = boardSkinById(boardSkinId);
    var disc = discSkinById(discSkinId);
    if (!isOwned(board.item, hasActiveSubscription: hasActiveSubscription)) {
      board = boardSkins.first;
    }
    if (!isOwned(disc.item, hasActiveSubscription: hasActiveSubscription)) {
      disc = discSkins.first;
    }
    if (board.id == disc.id) {
      for (final t in ReversiaBoardTheme.all) {
        if (t.id == board.id) return t;
      }
    }
    const base = ReversiaBoardTheme.classic;
    return ReversiaBoardTheme(
      id: '${board.id}+${disc.id}',
      label: '${board.item.name} × ${disc.item.name}',
      lightSquare: board.lightSquare,
      darkSquare: board.darkSquare,
      frontPieceColor: disc.frontColor,
      backPieceColor: disc.backColor,
      kingColor: base.kingColor,
      lastMoveColor: base.lastMoveColor,
      selectedBorderColor: base.selectedBorderColor,
      hintColor: base.hintColor,
      gridLineColor: board.gridLineColor,
      discGloss: disc.gloss,
    );
  }
}
