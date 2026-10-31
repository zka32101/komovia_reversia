import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:komovia_core/komovia_core.dart';

/// プレミアムサポーターの権限管理 - GoEnの`PurchaseService`/`User.
/// subscriptionActive`相当の役割だが、reversiaには大きなUserモデルが
/// 無いため、専用の小さなドキュメント`premium_entitlements/{uid}`で
/// 管理する。現時点のreversiaには「プレミアムでなければ使えない機能」
/// は存在しない - これは開発者を応援するための任意のサポーター購入
/// （月額/年額/買い切り）であり、ホーム画面にサポーターバッジを表示する
/// のみ。将来的に機能ゲートが必要になった場合も、このドキュメントの
/// `isCurrentlyActive`を読むだけで判定できる。
///
/// 権限の形は`PremiumEntitlement`として独自に持たず、komovia_coreの
/// `Entitlement`/`SubscriptionPlan`を使う（chessとgoenのPurchaseService
/// を比較して抽出された共通形 - core側のdoc comment参照）。Firestore側
/// の既存ドキュメント形式（`isActive`フィールドを保存しない、付与時点
/// で常にアクティブという前提）はこのサービスの変換関数
/// ([_toFirestore]/[_fromFirestore])で維持しているため、移行は不要。
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

  Entitlement _fromFirestore(Map<String, Object?> json) {
    final planName = json['plan'] as String?;
    final plan = planName == null
        ? null
        : SubscriptionPlan.values.firstWhere(
            (p) => p.name == planName,
            orElse: () => SubscriptionPlan.monthly,
          );
    return Entitlement(
      // 付与時点では常にアクティブとして保存している（grantEntitlement
      // 参照）。実際にまだ有効かどうかは期限切れを都度判定する
      // `isCurrentlyActive`で確認する - このフィールド自体は保存して
      // いない（旧`PremiumEntitlement`と同じFirestore形式を維持）。
      isActive: true,
      plan: plan,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  Map<String, Object?> _toFirestore(Entitlement entitlement) => {
        'plan': entitlement.plan?.name,
        'startedAt': entitlement.startedAt?.toIso8601String(),
        'expiresAt': entitlement.expiresAt?.toIso8601String(),
      };

  Future<Entitlement?> getEntitlement(String uid) async {
    final doc = await _docOf(uid).get();
    if (!doc.exists) return null;
    return _fromFirestore(doc.data()!);
  }

  Stream<Entitlement?> watchEntitlement(String uid) {
    return _docOf(uid).snapshots().map(
          (doc) => doc.exists ? _fromFirestore(doc.data()!) : null,
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
    DateTime? startedAt,
  }) async {
    final now = DateTime.now();
    if (skipIfAlreadyActive) {
      final existing = await getEntitlement(uid);
      if (existing != null && existing.isCurrentlyActive(now: now)) return;
    }

    final start = startedAt ?? now;
    final entitlement = Entitlement(
      isActive: true,
      plan: plan,
      startedAt: start,
      expiresAt: plan.entitlementLength == null
          ? null
          : start.add(plan.entitlementLength!),
    );
    await _docOf(uid).set(_toFirestore(entitlement));
  }

  /// ストアから復元された購入（`PurchaseStatus.restored`）を、**現在の**
  /// uidへ再び紐付ける。匿名認証のため再インストール/機種変更でuidが
  /// 変わると、以前のuidに保存された権限は見えなくなる - App Store審査
  /// ガイドライン3.1.1が求める「購入の復元」の実体はこの再紐付け。
  ///
  /// [originalPurchaseDate]が分かる場合はそこを起点に期限を計算し、
  /// 既に期限切れの月額/年額は復元しない（復元のたびに期限が「今から」
  /// 延長されてしまう抜け道を防ぐ）。買い切りは常に復元する。
  /// 権限を付与した（または既に有効だった）場合はtrueを返す。
  Future<bool> restoreEntitlement({
    required String uid,
    required SubscriptionPlan plan,
    DateTime? originalPurchaseDate,
  }) async {
    final now = DateTime.now();
    final length = plan.entitlementLength;
    if (length != null &&
        originalPurchaseDate != null &&
        !originalPurchaseDate.add(length).isAfter(now)) {
      return false;
    }
    final existing = await getEntitlement(uid);
    if (existing != null && existing.isCurrentlyActive(now: now)) return true;
    await grantEntitlement(
      uid: uid,
      plan: plan,
      startedAt: length == null ? now : originalPurchaseDate,
    );
    return true;
  }
}

extension ReversiaSubscriptionPlanDisplay on SubscriptionPlan {
  String get productId => switch (this) {
        SubscriptionPlan.monthly => PurchaseService.monthlyProductId,
        SubscriptionPlan.annual => PurchaseService.annualProductId,
        SubscriptionPlan.lifetime => PurchaseService.lifetimeProductId,
      };

  String get label => switch (this) {
        SubscriptionPlan.monthly => '月額プラン',
        SubscriptionPlan.annual => '年額プラン',
        SubscriptionPlan.lifetime => '買い切りプラン',
      };
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

  // lateで遅延初期化 - プラットフォームチャンネルの無い環境（テスト）
  // でこのクラスを生成/継承しただけで例外にならないようにする。
  late final InAppPurchase _iap = InAppPurchase.instance;

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

  /// 過去の購入をストアから再配信させる（App Store審査ガイドライン
  /// 3.1.1対応）。結果は[purchaseStream]に`PurchaseStatus.restored`として
  /// 非同期に届く。
  Future<void> restorePurchases() => _iap.restorePurchases();

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
