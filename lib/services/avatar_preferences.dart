import 'package:shared_preferences/shared_preferences.dart';

import '../src/reversia_avatar.dart';

/// テスト時に実際の`SharedPreferences`を介さずに差し替えられるようにする
/// ための最小インターフェース（`BoardThemePreferencesLike`と同じ役割）。
abstract class AvatarPreferencesLike {
  Future<ReversiaAvatar> getAvatar();
  Future<void> setAvatar(ReversiaAvatar avatar);
}

/// プレイヤーアバターの永続化 - `BoardThemePreferences`と同じく
/// `SharedPreferences`のみを使う端末ローカルな設定。
class AvatarPreferences implements AvatarPreferencesLike {
  static const _avatarIdKey = 'reversia_avatar_id';

  @override
  Future<ReversiaAvatar> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return ReversiaAvatar.byId(prefs.getString(_avatarIdKey));
  }

  @override
  Future<void> setAvatar(ReversiaAvatar avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarIdKey, avatar.id);
  }
}
