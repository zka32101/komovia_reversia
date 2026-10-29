import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reversia_challenge_code.dart';
import '../services/reversia_challenge_service.dart';

/// フレンド対戦（招待コード）機能のRiverpodラッパー。
/// `reversia_matching_provider.dart`と同じ役割分担。
final reversiaChallengeServiceProvider = Provider<ReversiaChallengeService>((ref) {
  return ReversiaChallengeService(FirebaseFirestore.instance);
});

final createReversiaChallengeProvider = Provider<
    Future<ReversiaChallengeCode> Function({
      required String hostUid,
      required String hostDisplayName,
    })>((ref) {
  final service = ref.watch(reversiaChallengeServiceProvider);
  return ({required hostUid, required hostDisplayName}) {
    return service.createChallenge(
      hostUid: hostUid,
      hostDisplayName: hostDisplayName,
    );
  };
});

final joinReversiaChallengeProvider = Provider<
    Future<ReversiaChallengeCode?> Function({
      required String code,
      required String guestUid,
      required String guestDisplayName,
    })>((ref) {
  final service = ref.watch(reversiaChallengeServiceProvider);
  return ({required code, required guestUid, required guestDisplayName}) {
    return service.joinChallenge(
      code: code,
      guestUid: guestUid,
      guestDisplayName: guestDisplayName,
    );
  };
});

final attachReversiaGameToChallengeProvider =
    Provider<Future<void> Function(String code, String gameId)>((ref) {
  final service = ref.watch(reversiaChallengeServiceProvider);
  return (code, gameId) => service.attachGameToChallenge(code, gameId);
});

/// ホストが自分の発行したコードの状態（ゲスト参加→gameId付与）を
/// リアルタイムに監視するためのストリーム。
final reversiaChallengeStreamProvider =
    StreamProvider.family<ReversiaChallengeCode?, String>((ref, code) {
  return ref.watch(reversiaChallengeServiceProvider).watchChallenge(code);
});
