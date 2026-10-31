import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart' show AvatarFrame;

import '../../l10n/app_localizations.dart';
import '../../models/reversia_game_stats.dart';
import '../../services/avatar_frame_preferences.dart';
import '../../services/avatar_preferences.dart';
import '../../services/reversia_game_stats_service.dart';
import '../../services/daily_reminder_preferences.dart';
import '../../services/local_notification_service.dart';
import '../../services/sound_feedback_preferences.dart';
import '../../src/reversia_avatar.dart';
import '../../src/reversia_avatar_frame.dart';
import '../../utils/reversia_move_feedback.dart';
import '../../services/auth_service.dart';
import 'account_screen.dart';
import 'cosmetic_shop_screen.dart';
import 'how_to_play_screen.dart';
import 'legal_document_screen.dart';
import 'paywall_screen.dart';

/// 設定画面 - 利用規約・プライバシーポリシー・プレミアムサポーター
/// （サインイン時のみ）への入口に加え、project-015の
/// `local_notification_service.dart`から移植したデイリーリマインダー
/// （「今日の1局」を知らせる端末ローカル通知）のオン/オフ・時刻設定、
/// project-015の`customization_provider.dart`から移植した着手フィード
/// バック（効果音・触覚）のオン/オフ設定、project-015の
/// `avatars_provider.dart`から移植したプレイヤーアバター選択（絵文字を
/// 選ぶだけの最小構成 - `reversia_avatar.dart`参照）を持つ。GoEnの
/// SettingsScreenのような大きな画面ではなく最小限の構成のまま。
class SettingsScreen extends StatefulWidget {
  SettingsScreen({
    super.key,
    this.uid,
    LocalNotificationServiceLike? notificationService,
    DailyReminderPreferencesLike? preferences,
    SoundFeedbackPreferencesLike? soundFeedbackPreferences,
    AvatarPreferencesLike? avatarPreferences,
    AvatarFramePreferencesLike? framePreferences,
    Future<ReversiaGameStats> Function(String uid)? statsLoader,
    this.authService,
  })  : notificationService =
            notificationService ?? const _DefaultNotificationService(),
        preferences = preferences ?? DailyReminderPreferences(),
        soundFeedbackPreferences =
            soundFeedbackPreferences ?? SoundFeedbackPreferences(),
        avatarPreferences = avatarPreferences ?? AvatarPreferences(),
        framePreferences = framePreferences ?? AvatarFramePreferences(),
        statsLoader = statsLoader ?? _defaultStatsLoader;

  /// フレームのアンロック判定に使う同期済みのAI対局記録を読む。
  /// Firestoreが使えない環境（テスト等）では初期値扱いにする。
  static Future<ReversiaGameStats> _defaultStatsLoader(String uid) async {
    try {
      return await ReversiaGameStatsService().getStats(uid);
    } catch (_) {
      return ReversiaGameStats.initial;
    }
  }

  final String? uid;
  final LocalNotificationServiceLike notificationService;
  final DailyReminderPreferencesLike preferences;
  final SoundFeedbackPreferencesLike soundFeedbackPreferences;
  final AvatarPreferencesLike avatarPreferences;
  final AvatarFramePreferencesLike framePreferences;
  final Future<ReversiaGameStats> Function(String uid) statsLoader;

  /// アカウント連携画面に渡すAuthService（テスト用に差し替え可能）。
  final AuthService? authService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _reminderEnabled = false;
  int _reminderHour = DailyReminderPreferences.defaultHour;
  int _reminderMinute = DailyReminderPreferences.defaultMinute;
  bool _loaded = false;
  bool _feedbackEnabled = true;
  ReversiaAvatar _avatar = ReversiaAvatar.defaultAvatar;
  ReversiaGameStats _stats = ReversiaGameStats.initial;
  String? _frameId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.preferences.isEnabled();
    final hour = await widget.preferences.getHour();
    final minute = await widget.preferences.getMinute();
    final feedbackEnabled = await widget.soundFeedbackPreferences.isEnabled();
    final avatar = await widget.avatarPreferences.getAvatar();
    final frameId = await widget.framePreferences.getFrameId();
    final uid = widget.uid;
    final stats =
        uid == null ? ReversiaGameStats.initial : await widget.statsLoader(uid);
    if (!mounted) return;
    setState(() {
      _reminderEnabled = enabled;
      _reminderHour = hour;
      _reminderMinute = minute;
      _feedbackEnabled = feedbackEnabled;
      _avatar = avatar;
      _frameId = frameId;
      _stats = stats;
      _loaded = true;
    });
  }

  Future<void> _pickAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<ReversiaAvatar>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsChooseAvatarTitle),
        children: [
          for (final avatar in ReversiaAvatar.all)
            RadioListTile<ReversiaAvatar>(
              title: Text('${avatar.emoji}  ${avatar.label}'),
              value: avatar,
              groupValue: _avatar,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await widget.avatarPreferences.setAvatar(selected);
    if (mounted) setState(() => _avatar = selected);
  }

  ReversiaAvatarFrame? get _selectedFrame =>
      ReversiaAvatarFrame.resolveSelected(_frameId, _stats);

  String _requirementText(AppLocalizations l10n, ReversiaAvatarFrame f) {
    switch (f.kind) {
      case FrameRequirementKind.gamesPlayed:
        return l10n.frameRequirementGames(f.threshold);
      case FrameRequirementKind.wins:
        return l10n.frameRequirementWins(f.threshold);
      case FrameRequirementKind.longestWinStreak:
        return l10n.frameRequirementStreak(f.threshold);
    }
  }

  Future<void> _pickFrame() async {
    final l10n = AppLocalizations.of(context)!;
    final unlocked = ReversiaAvatarFrame.unlockedIds(_stats);
    const noneSentinel = '';
    final current = _selectedFrame?.id ?? noneSentinel;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsChooseFrameTitle),
        children: [
          RadioListTile<String>(
            title: Text(l10n.settingsFrameNone),
            value: noneSentinel,
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
          for (final f in ReversiaAvatarFrame.all)
            AvatarFrame.isUnlocked(f.id, unlocked)
                ? RadioListTile<String>(
                    key: ValueKey('frame-${f.id}'),
                    secondary:
                        FramedAvatar(emoji: _avatar.emoji, frame: f, size: 32),
                    title: Text(f.frame.name),
                    value: f.id,
                    groupValue: current,
                    onChanged: (v) => Navigator.pop(ctx, v),
                  )
                : ListTile(
                    key: ValueKey('frame-${f.id}'),
                    enabled: false,
                    leading: const Icon(Icons.lock_outline),
                    title: Text(f.frame.name),
                    subtitle: Text(_requirementText(l10n, f)),
                  ),
        ],
      ),
    );
    if (selected == null) return;
    final frameId = selected == noneSentinel ? null : selected;
    await widget.framePreferences.setFrameId(frameId);
    if (mounted) setState(() => _frameId = frameId);
  }

  Future<void> _setFeedbackEnabled(bool value) async {
    await widget.soundFeedbackPreferences.setEnabled(value);
    reversiaFeedbackEnabled = value;
    if (mounted) setState(() => _feedbackEnabled = value);
  }

  String get _formattedTime =>
      '$_reminderHour:${_reminderMinute.toString().padLeft(2, '0')}';

  Future<void> _setReminderEnabled(bool value) async {
    if (value) {
      final granted = await widget.notificationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .settingsNotificationPermissionRequiredMessage)),
        );
        return;
      }
      await widget.notificationService.scheduleDailyReminder(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
    } else {
      await widget.notificationService.cancelDailyReminder();
    }
    await widget.preferences.setEnabled(value);
    if (mounted) setState(() => _reminderEnabled = value);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null) return;

    await widget.preferences.setTime(picked.hour, picked.minute);
    if (_reminderEnabled) {
      await widget.notificationService.scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
    if (mounted) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettingsTitle)),
      body: ListView(
        children: [
          if (_loaded)
            ListTile(
              leading:
                  FramedAvatar(emoji: _avatar.emoji, frame: _selectedFrame),
              title: Text(l10n.settingsAvatarLabel),
              subtitle: Text(_avatar.label),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickAvatar,
            ),
          if (_loaded)
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: Text(l10n.settingsAvatarFrameLabel),
              subtitle:
                  Text(_selectedFrame?.frame.name ?? l10n.settingsFrameNone),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickFrame,
            ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.cosmeticShopTitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CosmeticShopScreen(uid: widget.uid)),
            ),
          ),
          if (widget.uid != null)
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l10n.paywallTitle),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PaywallScreen(uid: widget.uid!)),
              ),
            ),
          if (_loaded) ...[
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.settingsDailyReminderLabel),
              subtitle: Text(
                _reminderEnabled
                    ? l10n.settingsDailyReminderOnSubtitle(_formattedTime)
                    : l10n.settingsOffLabel,
              ),
              value: _reminderEnabled,
              onChanged: _setReminderEnabled,
            ),
            if (_reminderEnabled)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(l10n.settingsReminderTimeLabel),
                subtitle: Text(_formattedTime),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _pickReminderTime,
              ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: Text(l10n.settingsMoveFeedbackLabel),
              subtitle: Text(_feedbackEnabled
                  ? l10n.settingsOnLabel
                  : l10n.settingsOffLabel),
              value: _feedbackEnabled,
              onChanged: _setFeedbackEnabled,
            ),
          ],
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l10n.accountLinkEntryTitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountScreen(authService: widget.authService),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l10n.howToPlayTitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicyTitle),
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
            title: Text(l10n.termsOfServiceTitle),
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

/// テスト時に実際の`flutter_local_notifications`プラグイン（プラット
/// フォームチャンネルが無い環境では例外を投げる）を呼ばずに済むよう、
/// `LocalNotificationService`の必要な3メソッドだけを抜いたインター
/// フェース。
abstract class LocalNotificationServiceLike {
  Future<bool> requestPermission();
  Future<void> scheduleDailyReminder({required int hour, required int minute});
  Future<void> cancelDailyReminder();
}

class _DefaultNotificationService implements LocalNotificationServiceLike {
  const _DefaultNotificationService();

  @override
  Future<bool> requestPermission() =>
      LocalNotificationService().requestPermission();

  @override
  Future<void> scheduleDailyReminder(
          {required int hour, required int minute}) =>
      LocalNotificationService()
          .scheduleDailyReminder(hour: hour, minute: minute);

  @override
  Future<void> cancelDailyReminder() =>
      LocalNotificationService().cancelDailyReminder();
}
