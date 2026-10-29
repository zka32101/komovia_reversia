import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../services/premium_entitlement_service.dart';
import '../../viewmodels/index.dart';

/// プレミアムサポーター画面 - GoEnの`PaywallScreen`と同じ構成
/// （月額/年額/買い切りの3プラン、ストアの実際の価格をIAPから取得）
/// だが、reversiaには現時点でプレミアムでなければ使えない機能は無い
/// ため、「開発者を応援する」という位置づけで案内する（存在しない機能
/// を宣伝しない）。購入すると、ホーム画面にサポーターバッジが表示
/// される。
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(premiumEntitlementProvider(uid)).value;
    final isPremium = entitlement?.isCurrentlyActive() ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('プレミアムサポーター')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Komovia Reversiaの開発を応援してくださる方向けのサポータープランです。'
              '現時点でプレミアムでなければ使えない機能はありませんが、'
              'ご購入いただくとホーム画面にサポーターバッジが表示されます。',
            ),
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
                        'すでにサポーターです（${entitlement!.plan!.label}）'
                        '${entitlement.expiresAt != null ? ' - ${entitlement.expiresAt!.toLocal().toString().split(' ').first}まで有効' : ''}',
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ご購入ありがとうございます！')));
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
    final productAsync = ref.watch(subscriptionProductProvider(widget.plan));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(widget.plan.label),
        subtitle: productAsync.when(
          data: (product) => Text(product?.price ?? '価格を取得できませんでした'),
          loading: () => const Text('価格を取得中...'),
          error: (err, _) => const Text('価格を取得できませんでした'),
        ),
        trailing: FilledButton(
          onPressed: _isPurchasing ? null : _purchase,
          child: _isPurchasing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('購入する'),
        ),
      ),
    );
  }
}
