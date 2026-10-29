import 'package:flutter/material.dart';

import 'legal_document_screen.dart';
import 'paywall_screen.dart';

/// 設定画面 - 利用規約・プライバシーポリシーへの入口に加え、サインイン
/// 済みであればプレミアムサポーター画面への入口も持つ。reversiaには
/// まだ通知のオン/オフ等のユーザー設定項目が無いため、GoEnの
/// SettingsScreenのような大きな画面ではなく最小限の構成とする。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          if (uid != null)
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('プレミアムサポーター'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaywallScreen(uid: uid!)),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalDocumentScreen(
                  kind: LegalDocumentKind.privacyPolicy,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalDocumentScreen(
                  kind: LegalDocumentKind.termsOfService,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
