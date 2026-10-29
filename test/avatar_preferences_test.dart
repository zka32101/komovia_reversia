import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/avatar_preferences.dart';
import 'package:komovia_reversia/src/reversia_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReversiaAvatar.byId', () {
    test('resolves a known id', () {
      expect(ReversiaAvatar.byId('fox'), ReversiaAvatar.all.firstWhere((a) => a.id == 'fox'));
    });

    test('falls back to the default avatar for null or an unknown id', () {
      expect(ReversiaAvatar.byId(null), ReversiaAvatar.defaultAvatar);
      expect(ReversiaAvatar.byId('does-not-exist'), ReversiaAvatar.defaultAvatar);
    });
  });

  group('AvatarPreferences', () {
    test('defaults to the default avatar when nothing was ever saved', () async {
      final prefs = AvatarPreferences();
      expect(await prefs.getAvatar(), ReversiaAvatar.defaultAvatar);
    });

    test('persists and reloads the selected avatar', () async {
      final prefs = AvatarPreferences();
      final dragon = ReversiaAvatar.byId('dragon');
      await prefs.setAvatar(dragon);
      expect(await prefs.getAvatar(), dragon);
    });
  });
}
