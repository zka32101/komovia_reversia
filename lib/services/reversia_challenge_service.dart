import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reversia_challenge_code.dart';

/// フレンド対戦用の招待コード発行・参加サービス。
/// `ReversiaMatchingService`の「成立はトランザクション内で候補者の
/// 状態を再確認してから」という方針と、`attachGameToMatch`の
/// 「マッチ成立→(別ステップで)対局作成→gameId付与」という2段階
/// パターンを、不特定多数からのランダムマッチングではなく1つの
/// コードへの参加という形にそのまま当てはめたもの。
class ReversiaChallengeService {
  ReversiaChallengeService(this._firestore);

  final FirebaseFirestore _firestore;

  static const int _codeLength = 6;
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _codes =>
      _firestore.collection('reversia_challenge_codes');

  String _randomCode(Random random) {
    return List.generate(
      _codeLength,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  /// 新しい招待コードを発行する。衝突（既存コードと同じ文字列）は
  /// 極めて稀だが、念のため数回まで再試行する。
  Future<ReversiaChallengeCode> createChallenge({
    required String hostUid,
    required String hostDisplayName,
    Random? random,
  }) async {
    final rng = random ?? Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode(rng);
      final ref = _codes.doc(code);
      final created = await _firestore.runTransaction<ReversiaChallengeCode?>(
        (transaction) async {
          final existing = await transaction.get(ref);
          if (existing.exists) return null;
          final challenge = ReversiaChallengeCode(
            code: code,
            hostUid: hostUid,
            hostDisplayName: hostDisplayName,
            status: 'waiting',
            createdAt: DateTime.now(),
          );
          transaction.set(ref, challenge.toFirestore());
          return challenge;
        },
      );
      if (created != null) return created;
    }
    throw StateError('招待コードの発行に失敗しました。もう一度お試しください');
  }

  Future<ReversiaChallengeCode?> getChallenge(String code) async {
    final doc = await _codes.doc(code.toUpperCase()).get();
    if (!doc.exists) return null;
    return ReversiaChallengeCode.fromFirestore(doc);
  }

  Stream<ReversiaChallengeCode?> watchChallenge(String code) {
    return _codes.doc(code.toUpperCase()).snapshots().map(
          (doc) => doc.exists ? ReversiaChallengeCode.fromFirestore(doc) : null,
        );
  }

  /// [code]に参加する。成立の書き込みはトランザクション内で
  /// 「まだwaitingか」「ホスト自身ではないか」を再確認してから行い、
  /// 2人がほぼ同時に同じコードへ参加しても一方だけが成立する。
  /// 成立すれば更新後の[ReversiaChallengeCode]を返し、無効な
  /// コード・自分自身のコード・既に参加済みのコードならnullを返す。
  Future<ReversiaChallengeCode?> joinChallenge({
    required String code,
    required String guestUid,
    required String guestDisplayName,
  }) {
    final ref = _codes.doc(code.toUpperCase());
    return _firestore.runTransaction<ReversiaChallengeCode?>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return null;
      final challenge = ReversiaChallengeCode.fromFirestore(snapshot);
      if (challenge.status != 'waiting') return null;
      if (challenge.hostUid == guestUid) return null;

      final updated = ReversiaChallengeCode(
        code: challenge.code,
        hostUid: challenge.hostUid,
        hostDisplayName: challenge.hostDisplayName,
        guestUid: guestUid,
        guestDisplayName: guestDisplayName,
        status: 'matched',
        gameId: challenge.gameId,
        createdAt: challenge.createdAt,
      );
      transaction.update(ref, {
        'guestUid': guestUid,
        'guestDisplayName': guestDisplayName,
        'status': 'matched',
      });
      return updated;
    });
  }

  Future<void> attachGameToChallenge(String code, String gameId) {
    return _codes.doc(code.toUpperCase()).update({'gameId': gameId});
  }
}
