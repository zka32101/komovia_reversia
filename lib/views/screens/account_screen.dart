import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';

/// 「機種変更に備えてアカウントを連携」画面。komovia_goの
/// `AuthService.linkAnonymousToEmail`/`deleteAccount`と同じ考え方
/// （匿名ログインのuidをそのまま残すLINK）を、設定画面から辿れる独立
/// 画面として提供する。
///
/// - ゲスト（匿名）: メール/パスワードを連携してuidを恒久化する、または
///   別端末で連携済みのアカウントにログインする
/// - 連携済み: 連携先を表示
/// - 共通: 確認ダイアログ付きのアカウント削除
class AccountScreen extends StatefulWidget {
  AccountScreen({super.key, AuthService? authService})
      : authService = authService ?? AuthService();

  final AuthService authService;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _linkEmail = TextEditingController();
  final _linkPassword = TextEditingController();
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _linkEmail.dispose();
    _linkPassword.dispose();
    _signInEmail.dispose();
    _signInPassword.dispose();
    super.dispose();
  }

  String _errorText(AppLocalizations l10n, Object error) {
    final code = error is AuthServiceException ? error.code : 'unknown';
    switch (code) {
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return l10n.accountErrorEmailInUse;
      case 'invalid-email':
        return l10n.accountErrorInvalidEmail;
      case 'weak-password':
        return l10n.accountErrorWeakPassword;
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return l10n.accountErrorWrongCredentials;
      case 'requires-recent-login':
        return l10n.accountErrorRequiresRecentLogin;
      default:
        return l10n.accountErrorGeneric(code);
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() {
    final l10n = AppLocalizations.of(context)!;
    return _run(
      () => widget.authService.linkWithEmail(
        email: _linkEmail.text,
        password: _linkPassword.text,
      ),
      l10n.accountLinkSuccessMessage,
    );
  }

  Future<void> _signIn() {
    final l10n = AppLocalizations.of(context)!;
    return _run(
      () => widget.authService.signInWithEmail(
        email: _signInEmail.text,
        password: _signInPassword.text,
      ),
      l10n.accountSignInSuccessMessage,
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountDeleteDialogTitle),
        content: Text(l10n.accountDeleteDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.accountDeleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () async {
        await widget.authService.deleteAccount();
      },
      l10n.accountDeleteSuccessMessage,
    );
  }

  Widget _emailPasswordFields(
    AppLocalizations l10n,
    TextEditingController email,
    TextEditingController password,
    String keyPrefix,
  ) {
    return Column(
      children: [
        TextField(
          key: Key('${keyPrefix}_email'),
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: l10n.accountEmailLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key('${keyPrefix}_password'),
          controller: password,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.accountPasswordLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = widget.authService.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isGuest
                ? l10n.accountGuestStatus
                : l10n.accountLinkedStatus(user.email ?? ''),
          ),
          if (isGuest && user != null) ...[
            const SizedBox(height: 16),
            _emailPasswordFields(l10n, _linkEmail, _linkPassword, 'link'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _link,
              child: Text(l10n.accountLinkButton),
            ),
          ],
          if (isGuest) ...[
            const Divider(height: 40),
            Text(
              l10n.accountSignInSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.accountSignInDescription),
            const SizedBox(height: 8),
            _emailPasswordFields(l10n, _signInEmail, _signInPassword, 'signin'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _signIn,
              child: Text(l10n.accountSignInButton),
            ),
          ],
          if (user != null) ...[
            const Divider(height: 40),
            Text(l10n.accountDeleteDescription),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _busy ? null : _confirmDelete,
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(l10n.accountDeleteButton),
            ),
          ],
        ],
      ),
    );
  }
}
