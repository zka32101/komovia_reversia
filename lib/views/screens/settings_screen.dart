import 'package:flutter/material.dart';

import '../../services/avatar_preferences.dart';
import '../../services/daily_reminder_preferences.dart';
import '../../services/local_notification_service.dart';
import '../../services/sound_feedback_preferences.dart';
import '../../src/reversia_avatar.dart';
import '../../utils/reversia_move_feedback.dart';
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
  })  : notificationService = notificationService ?? const _DefaultNotificationService(),
        preferences = preferences ?? DailyReminderPreferences(),
        soundFeedbackPreferences =
            soundFeedbackPreferences ?? SoundFeedbackPreferences(),
        avatarPreferences = avatarPreferences ?? AvatarPreferences();

  final String? uid;
  final LocalNotificationServiceLike notificationService;
  final DailyReminderPreferencesLike preferences;
  final SoundFeedbackPreferencesLike soundFeedbackPreferences;
  final AvatarPreferencesLike avatarPreferences;

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
    if (!mounted) return;
    setState(() {
      _reminderEnabled = enabled;
      _reminderHour = hour;
      _reminderMinute = minute;
      _feedbackEnabled = feedbackEnabled;
      _avatar = avatar;
      _loaded = true;
    });
  }

  Future<void> _pickAvatar() async {
    final selected = await showDialog<ReversiaAvatar>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('アバターを選ぶ'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('通知の許可が必要です')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          if (_loaded)
            ListTile(
              leading: Text(_avatar.emoji, style: const TextStyle(fontSize: 28)),
              title: const Text('アバター'),
              subtitle: Text(_avatar.label),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickAvatar,
            ),
          if (widget.uid != null)
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('プレミアムサポーター'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaywallScreen(uid: widget.uid!)),
              ),
            ),
          if (_loaded) ...[
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('デイリーリマインダー'),
              subtitle: Text(_reminderEnabled ? '毎日 $_formattedTime に通知' : 'オフ'),
              value: _reminderEnabled,
              onChanged: _setReminderEnabled,
            ),
            if (_reminderEnabled)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('通知時刻'),
                subtitle: Text(_formattedTime),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _pickReminderTime,
              ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('着手の効果音・バイブ'),
              subtitle: Text(_feedbackEnabled ? 'オン' : 'オフ'),
              value: _feedbackEnabled,
              onChanged: _setFeedbackEnabled,
            ),
          ],
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('遊び方'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
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
  Future<bool> requestPermission() => LocalNotificationService().requestPermission();

  @override
  Future<void> scheduleDailyReminder({required int hour, required int minute}) =>
      LocalNotificationService().scheduleDailyReminder(hour: hour, minute: minute);

  @override
  Future<void> cancelDailyReminder() => LocalNotificationService().cancelDailyReminder();
}
