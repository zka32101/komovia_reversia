import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// プレミアムサポーターの権限管理 - GoEnの`PurchaseService`/`User.
/// subscriptionActive`相当の役割だが、reversiaには大きなUserモデルが
/// 無いため、専用の小さなドキュメント`premium_entitlements/{uid}`で
/// 管理する。現時点のreversiaには「プレミアムでなければ使えない機能」
/// は存在しない - これは開発者を応援するための任意のサポーター購入
/// （月額/年額/買い切り）であり、ホーム画面にサポーターバッジを表示する
/// のみ。将来的に機能ゲートが必要になった場合も、このドキュメントの
/// `isActiveAt`を読むだけで判定できる。
///
/// 他のKomoviaシリーズ（GoEn）と同じく、App Store/Play Storeの領収書を
/// サーバー側で検証するCloud Functionsが無いため、クライアントが
/// `grantEntitlement`を直接呼べる = 既知のクライアント信頼ギャップ
/// （バグではなく、サーバーレス構成の正直な限界として記録）。
class PremiumEntitlementService {
  PremiumEntitlementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _docOf(String uid) =>
      _firestore.collection('premium_entitlements').doc(uid);

  Future<PremiumEntitlement?> getEntitlement(String uid) async {
    final doc = await _docOf(uid).get();
    if (!doc.exists) return null;
    return PremiumEntitlement.fromJson(doc.data()!);
  }

  Stream<PremiumEntitlement?> watchEntitlement(String uid) {
    return _docOf(uid).snapshots().map(
          (doc) => doc.exists ? PremiumEntitlement.fromJson(doc.data()!) : null,
        );
  }

  /// [plan]の権限を付与する。すでに有効な権限がある場合、
  /// [skipIfAlreadyActive]がtrueなら何もしない - `in_app_purchase`は
  /// 未承認のトランザクションをアプリ起動ごとに再配信するため、既に
  /// 有効な権限の有効期限をそのたびに「今から」へ延長してしまわない
  /// ようにするガード（GoEnの`_grantEntitlement`の
  /// `skipIfAlreadyActive`と同じ役割）。
  Future<void> grantEntitlement({
    required String uid,
    required SubscriptionPlan plan,
    bool skipIfAlreadyActive = false,
  }) async {
    final now = DateTime.now();
    if (skipIfAlreadyActive) {
      final existing = await getEntitlement(uid);
      if (existing != null && existing.isActiveAt(now)) return;
    }

    final entitlement = PremiumEntitlement(
      plan: plan,
      startedAt: now,
      expiresAt: plan.entitlementLength == null
          ? null
          : now.add(plan.entitlementLength!),
    );
    await _docOf(uid).set(entitlement.toJson());
  }
}

enum SubscriptionPlan { monthly, annual, lifetime }

extension SubscriptionPlanProductId on SubscriptionPlan {
  String get productId => switch (this) {
        SubscriptionPlan.monthly => PurchaseService.monthlyProductId,
        SubscriptionPlan.annual => PurchaseService.annualProductId,
        SubscriptionPlan.lifetime => PurchaseService.lifetimeProductId,
      };

  /// 購入時点からの権限の有効期間。nullは「無期限（買い切り）」。
  Duration? get entitlementLength => switch (this) {
        SubscriptionPlan.monthly => const Duration(days: 30),
        SubscriptionPlan.annual => const Duration(days: 365),
        SubscriptionPlan.lifetime => null,
      };

  String get label => switch (this) {
        SubscriptionPlan.monthly => '月額プラン',
        SubscriptionPlan.annual => '年額プラン',
        SubscriptionPlan.lifetime => '買い切りプラン',
      };
}

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.plan,
    required this.startedAt,
    this.expiresAt,
  });

  final SubscriptionPlan plan;
  final DateTime startedAt;
  final DateTime? expiresAt;

  bool isActiveAt(DateTime time) =>
      expiresAt == null || expiresAt!.isAfter(time);

  bool get isActive => isActiveAt(DateTime.now());

  Map<String, Object?> toJson() => {
        'plan': plan.name,
        'startedAt': startedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory PremiumEntitlement.fromJson(Map<String, Object?> json) {
    return PremiumEntitlement(
      plan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == json['plan'],
        orElse: () => SubscriptionPlan.monthly,
      ),
      startedAt: DateTime.parse(json['startedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}

/// プラットフォームの`in_app_purchase`プラグインの薄いラッパー -
/// GoEnの`PurchaseService`と同じ役割（サードパーティのアカウントは
/// 不要だが、プロダクトIDは事前にApp Store Connect/Play Consoleで
/// 作成しておく必要がある）。
class PurchaseService {
  static const String monthlyProductId = 'reversia_premium_monthly';
  static const String annualProductId = 'reversia_premium_annual';
  static const String lifetimeProductId = 'reversia_premium_lifetime';
  static const Set<String> productIds = {
    monthlyProductId,
    annualProductId,
    lifetimeProductId,
  };

  final InAppPurchase _iap = InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// 単一プロダクトのストア情報（価格・通貨）を取得する。ストアに
  /// 到達できない、またはプロダクトが未設定の場合はnullを返す
  /// （例外にしない）ことで、呼び出し側が偽の成功を出さず正直な
  /// 「利用不可」表示を出せるようにする。
  Future<ProductDetails?> fetchProduct(String productId) async {
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      debugPrint('Failed to query product $productId: ${response.error}');
      return null;
    }
    if (response.notFoundIDs.contains(productId) || response.productDetails.isEmpty) {
      debugPrint('Product not found in store: $productId');
      return null;
    }
    return response.productDetails.first;
  }

  /// プラットフォームの購入フローを開始する。結果は戻り値ではなく
  /// [purchaseStream]経由で非同期に届く。
  Future<bool> buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// トランザクションをプラットフォームに確認応答する。成功後は必須
  /// （呼ばないとストアが未完了扱いにし、最終的に自動返金される）。
  Future<void> completePurchase(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      return _iap.completePurchase(purchase);
    }
    return Future.value();
  }
}

/// ストアまたはプロダクトが利用できないために購入処理を開始できない
/// ことを表す（ユーザーによるキャンセルや決済失敗とは別物）- GoEnの
/// `PurchaseUnavailableException`と同じ役割。
class PurchaseUnavailableException implements Exception {
  PurchaseUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}
