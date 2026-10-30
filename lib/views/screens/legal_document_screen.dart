import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 利用規約・プライバシーポリシー画面 - GoEnの`LegalDocumentScreen`と同じ
/// 役割。本文はこのアプリが実際に使っている機能のみに絞っている -
/// Firebase Authentication（匿名サインインのみ）、Cloud Firestore、
/// Firebase Crashlytics。GoEnにあるAnalytics/決済（IAP）に関する記述は
/// reversiaには該当する機能が無いため含めていない。
/// あくまで雛形であり、実際のストア提出前には開発者自身の連絡先情報等を
/// 確認・補完した上で法務レビューを受けることを前提とする。
enum LegalDocumentKind { privacyPolicy, termsOfService }

const _lastUpdated = '2026-10-29';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPrivacy = kind == LegalDocumentKind.privacyPolicy;
    final title = isPrivacy ? l10n.privacyPolicyTitle : l10n.termsOfServiceTitle;
    final body = isPrivacy
        ? l10n.privacyPolicyBodyText(_lastUpdated)
        : l10n.termsOfServiceBodyText(_lastUpdated);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
