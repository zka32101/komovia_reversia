import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../services/premium_entitlement_service.dart';
import '../../viewmodels/index.dart';

/// プレミアムサポーター画面 - GoEnの`PaywallScreen`と同じ構成
/// （月額/年額/買い切りの3プラン、ストアの実際の価格をIAPから取得）
/// だが、reversiaには現時点でプレミアムでなければ使えない機能は無い
/// ため、「開発者を応援する」という位置づけで案内する（存在しない機能
/// を宣伝しない）。購入すると、ホーム画面にサポーターバッジが表示
/// される。
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isRestoring = false;

  String get uid => widget.uid;

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isRestoring = true);
    try {
      final restored = await ref.read(restorePurchasesProvider)(uid);
      messenger.showSnackBar(SnackBar(
        content: Text(restored
            ? l10n.paywallRestoreSuccessMessage
            : l10n.paywallRestoreNoneFoundMessage),
      ));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.paywallRestoreFailedMessage('$e'))),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entitlement = ref.watch(premiumEntitlementProvider(uid)).value;
    final isPremium = entitlement?.isCurrentlyActive() ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paywallTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.paywallDescription),
            const SizedBox(height: 20),
            if (isPremium)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entitlement!.expiresAt != null
                            ? l10n.paywallAlreadySupporterWithExpiryMessage(
                                entitlement.plan!.label,
                                entitlement.expiresAt!.toLocal().toString().split(' ').first,
                              )
                            : l10n.paywallAlreadySupporterMessage(entitlement.plan!.label),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: SubscriptionPlan.values
                    .map((plan) => _PlanCard(uid: uid, plan: plan))
                    .toList(),
              ),
            const SizedBox(height: 12),
            // App Store審査ガイドライン3.1.1: 非消耗型（買い切り）を販売する
            // 場合、購入の復元手段が必須。サポーター状態に関わらず常に表示。
            Center(
              child: TextButton.icon(
                key: const Key('restorePurchasesButton'),
                onPressed: _isRestoring ? null : _restore,
                icon: _isRestoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore),
                label: Text(l10n.paywallRestoreButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.uid, required this.plan});

  final String uid;
  final SubscriptionPlan plan;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _isPurchasing = false;

  Future<void> _purchase() async {
    setState(() => _isPurchasing = true);
    try {
      await ref.read(purchaseSubscriptionProvider)(widget.uid, widget.plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.paywallPurchaseThanksMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final productAsync = ref.watch(subscriptionProductProvider(widget.plan));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(widget.plan.label),
        subtitle: productAsync.when(
          data: (product) => Text(product?.price ?? l10n.paywallPriceUnavailableMessage),
          loading: () => Text(l10n.paywallPriceLoadingMessage),
          error: (err, _) => Text(l10n.paywallPriceUnavailableMessage),
        ),
        trailing: FilledButton(
          onPressed: _isPurchasing ? null : _purchase,
          child: _isPurchasing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.paywallPurchaseButton),
        ),
      ),
    );
  }
}
