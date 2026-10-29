import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/tournament_service.dart';
import 'notification_provider.dart';

final tournamentServiceProvider = Provider<TournamentService>(
  (ref) => TournamentService(
    notifications: ref.watch(notificationServiceProvider),
  ),
);

final tournamentsStreamProvider = StreamProvider<List<Tournament>>(
  (ref) => ref.watch(tournamentServiceProvider).tournamentsStream(),
);

final tournamentMatchesStreamProvider =
    StreamProvider.family<List<TournamentMatch>, String>(
  (ref, tournamentId) =>
      ref.watch(tournamentServiceProvider).matchesStream(tournamentId),
);

final createTournamentProvider = Provider(
  (ref) => ({
    required String name,
    required String description,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
    int maxParticipants = 8,
    String format = 'single_elimination',
    int boardSize = 6,
  }) =>
      ref.read(tournamentServiceProvider).createTournament(
            name: name,
            description: description,
            createdBy: createdBy,
            startDate: startDate,
            endDate: endDate,
            maxParticipants: maxParticipants,
            format: format,
            boardSize: boardSize,
          ),
);

final joinTournamentProvider = Provider(
  (ref) => (String tournamentId, String uid) =>
      ref.read(tournamentServiceProvider).joinTournament(tournamentId, uid),
);

final startTournamentProvider = Provider(
  (ref) => (String tournamentId, Map<String, String> displayNames) => ref
      .read(tournamentServiceProvider)
      .startTournament(tournamentId, displayNames),
);

final tournamentStandingsProvider =
    FutureProvider.family<List<TournamentStandingEntry>, String>(
  (ref, tournamentId) =>
      ref.watch(tournamentServiceProvider).getStandings(tournamentId),
);

final recordMatchResultProvider = Provider(
  (ref) => (
    String tournamentId,
    String matchId,
    String winnerUid,
    Map<String, String> displayNames,
  ) =>
      ref.read(tournamentServiceProvider).recordMatchResult(
            tournamentId,
            matchId,
            winnerUid,
            displayNames,
          ),
);
