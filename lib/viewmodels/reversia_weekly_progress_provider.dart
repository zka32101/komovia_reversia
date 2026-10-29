import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reversia_weekly_progress.dart';
import '../services/reversia_weekly_progress_service.dart';
import 'auth_provider.dart';

final reversiaWeeklyProgressServiceProvider = Provider<ReversiaWeeklyProgressService>(
  (ref) => ReversiaWeeklyProgressService(FirebaseFirestore.instance),
);

/// 自分自身の今週の進捗。未サインインならnull。
final myReversiaWeeklyProgressProvider = StreamProvider<ReversiaWeeklyProgress?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(reversiaWeeklyProgressServiceProvider).watchProgress(uid);
});
