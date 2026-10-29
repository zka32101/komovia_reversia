import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/premium_entitlement_service.dart';
import 'auth_provider.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) => PurchaseService());

final premiumEntitlementServiceProvider =
    Provider<PremiumEntitlementService>((ref) => PremiumEntitlementService());

/// [uid]のストア情報（価格・通貨）。ストア未到達/未設定ならnull。
final subscriptionProductProvider =
    FutureProvider.family<ProductDetails?, SubscriptionPlan>((ref, plan) {
  return ref.watch(purchaseServiceProvider).fetchProduct(plan.productId);
});

/// [uid]の現在のプレミアム権限状態（買い切りなら無期限、月額/年額なら
/// `expiresAt`を過ぎるとfalseになる）。
final premiumEntitlementProvider =
    StreamProvider.family<PremiumEntitlement?, String>((ref, uid) {
  return ref.watch(premiumEntitlementServiceProvider).watchEntitlement(uid);
});

final isPremiumProvider = Provider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  final entitlement = ref.watch(premiumEntitlementProvider(uid)).value;
  return entitlement?.isActive ?? false;
});

/// アプリが起動している間、インタラクティブな購入フローとは無関係に
/// 常時購入ストリームを監視する。`InAppPurchase.purchaseStream`は
/// `completePurchase`で確認応答されなかったトランザクションを次回起動
/// 時に再配信するため、この監視が常時動いていないと、ストア側は決済
/// 完了済みと見なしているのに権限が付与されないまま取り残される
/// ユーザーが出てしまう（GoEnの`purchaseRecoveryProvider`と同じ役割）。
/// アプリのルート付近で一度watchしておく想定。
final purchaseRecoveryProvider = Provider<void>((ref) {
  // `FirebaseFirestore.instance`も`InAppPurchase.instance.purchaseStream`
  // の購読も、プラットフォームチャンネルの無い環境（`flutter test`含む）
  // では即座に例外を投げることがある - このプロバイダーはアプリ起動時
  // に無条件でwatchされる(main.dartの`_RootScreenState.build`参照)ため、
  // ここで失敗するとアプリ全体の起動がブロックされてしまう。
  // best-effortで握りつぶす。
  late final PurchaseService purchaseService;
  late final PremiumEntitlementService entitlementService;
  late final StreamSubscription<List<PurchaseDetails>> subscription;
  try {
    purchaseService = ref.watch(purchaseServiceProvider);
    entitlementService = ref.watch(premiumEntitlementServiceProvider);
    subscription = purchaseService.purchaseStream.listen((purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          SubscriptionPlan? plan;
          try {
            plan = SubscriptionPlan.values.firstWhere((p) => p.productId == purchase.productID);
          } catch (_) {
            plan = null;
          }
          if (plan == null) {
            debugPrint('Unknown product in purchaseStream: ${purchase.productID}');
            break;
          }
          final uid = ref.read(currentUidProvider);
          if (uid == null) break;
          try {
            await entitlementService.grantEntitlement(
              uid: uid,
              plan: plan,
              skipIfAlreadyActive: true,
            );
            await purchaseService.completePurchase(purchase);
          } catch (e) {
            // completePurchaseを呼ばない - ストアに再配信させ、次回この
            // リスナーがもう一度試行できるようにする。
            debugPrint('Failed to sync purchase ${purchase.productID}: $e');
          }
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          await purchaseService.completePurchase(purchase);
        case PurchaseStatus.pending:
          break;
      }
    }
    });
  } catch (e) {
    debugPrint('purchaseRecoveryProvider could not subscribe: $e');
    return;
  }

  ref.onDispose(subscription.cancel);
});

/// [plan]を購入する。成功時は権限を付与する。ストア/プロダクトが利用
/// できない場合は偽の成功を返さず[PurchaseUnavailableException]を
/// throwする。
final purchaseSubscriptionProvider =
    Provider<Future<void> Function(String uid, SubscriptionPlan plan)>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final entitlementService = ref.watch(premiumEntitlementServiceProvider);

  return (uid, plan) async {
    final available = await purchaseService.isAvailable();
    if (!available) {
      throw PurchaseUnavailableException('この端末では購入機能を利用できません。');
    }

    final product = await purchaseService.fetchProduct(plan.productId);
    if (product == null) {
      throw PurchaseUnavailableException('このプランは現在ご購入いただけません。しばらくしてから再度お試しください。');
    }

    final completer = Completer<PurchaseDetails>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = purchaseService.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != product.id || completer.isCompleted) continue;
          switch (purchase.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              completer.complete(purchase);
            case PurchaseStatus.error:
              purchaseService.completePurchase(purchase);
              completer.completeError(purchase.error ?? Exception('Purchase failed'));
            case PurchaseStatus.canceled:
              purchaseService.completePurchase(purchase);
              completer.completeError(Exception('canceled'));
            case PurchaseStatus.pending:
              break;
          }
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      final started = await purchaseService.buy(product);
      if (!started) {
        throw Exception('Failed to start purchase flow');
      }

      final purchase = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('Purchase timed out'),
      );

      await entitlementService.grantEntitlement(uid: uid, plan: plan);
      await purchaseService.completePurchase(purchase);
    } finally {
      await subscription.cancel();
    }
  };
});
