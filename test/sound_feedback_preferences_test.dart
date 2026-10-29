import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/services/sound_feedback_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to enabled', () async {
    final prefs = SoundFeedbackPreferences();
    expect(await prefs.isEnabled(), isTrue);
  });

  test('persists and reloads a disabled setting', () async {
    final prefs = SoundFeedbackPreferences();
    await prefs.setEnabled(false);
    expect(await prefs.isEnabled(), isFalse);
  });

  test('persists and reloads a re-enabled setting', () async {
    final prefs = SoundFeedbackPreferences();
    await prefs.setEnabled(false);
    await prefs.setEnabled(true);
    expect(await prefs.isEnabled(), isTrue);
  });
}
