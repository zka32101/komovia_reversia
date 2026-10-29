import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/komovia_reversia.dart';
import 'package:komovia_reversia/services/board_theme_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReversiaBoardTheme.byId', () {
    test('resolves a known id', () {
      expect(ReversiaBoardTheme.byId('sumi'), ReversiaBoardTheme.sumi);
      expect(ReversiaBoardTheme.byId('emerald'), ReversiaBoardTheme.emerald);
    });

    test('falls back to classic for null or an unknown id', () {
      expect(ReversiaBoardTheme.byId(null), ReversiaBoardTheme.classic);
      expect(ReversiaBoardTheme.byId('does-not-exist'), ReversiaBoardTheme.classic);
    });
  });

  group('BoardThemePreferences', () {
    test('defaults to classic when nothing was ever saved', () async {
      final prefs = BoardThemePreferences();
      expect(await prefs.getTheme(), ReversiaBoardTheme.classic);
    });

    test('persists and reloads the selected theme', () async {
      final prefs = BoardThemePreferences();
      await prefs.setTheme(ReversiaBoardTheme.emerald);
      expect(await prefs.getTheme(), ReversiaBoardTheme.emerald);
    });
  });
}
