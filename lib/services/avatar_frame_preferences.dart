import 'package:shared_preferences/shared_preferences.dart';

/// テスト時に差し替えられるようにする最小インターフェース。
abstract class AvatarFramePreferencesLike {
  Future<String?> getFrameId();
  Future<void> setFrameId(String? frameId);
}

/// 選択中のアバターフレームidの永続化 - `AvatarPreferences`と同じく
/// 端末ローカル（このアプリには同期されるプロフィールドキュメントが
/// 無いため）。アンロック判定自体は同期済みの`reversia_game_stats`から
/// 都度導出するので、ここには選択だけを保存する。`null`はフレームなし。
class AvatarFramePreferences implements AvatarFramePreferencesLike {
  static const _frameIdKey = 'reversia_avatar_frame_id';

  @override
  Future<String?> getFrameId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_frameIdKey);
  }

  @override
  Future<void> setFrameId(String? frameId) async {
    final prefs = await SharedPreferences.getInstance();
    if (frameId == null) {
      await prefs.remove(_frameIdKey);
    } else {
      await prefs.setString(_frameIdKey, frameId);
    }
  }
}
