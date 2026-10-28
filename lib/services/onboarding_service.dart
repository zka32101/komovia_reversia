import 'package:shared_preferences/shared_preferences.dart';

/// Whether the player has completed the one-time rules onboarding
/// (`OnboardingScreen`). Stored locally (not Firestore) on purpose - this
/// app has no Firebase dependency at all yet, and even once it does, this
/// is a per-device "have I seen this" flag, not account data.
///
/// Same shape as komovia_shogi's `OnboardingService` (the first app to
/// implement this).
class OnboardingService {
  static const _completedKey = 'onboarding_completed';

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
