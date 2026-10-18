import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

abstract interface class LeaderboardRepository {
  Future<List<WeeklyLeaderboardEntry>> weeklyLeaderboard({
    required int weekOffset,
  });
}

class WeeklyLeaderboardEntry {
  const WeeklyLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.fullName,
    required this.points,
  });

  final int rank;
  final int userId;
  final String fullName;
  final int points;

  factory WeeklyLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      WeeklyLeaderboardEntry(
        rank: (json['rank'] as num).toInt(),
        userId: (json['user_id'] as num).toInt(),
        fullName: json['full_name'] as String,
        points: (json['weekly_points'] as num).toInt(),
      );
}

class LeaderboardException implements Exception {
  const LeaderboardException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LeaderboardService implements LeaderboardRepository {
  LeaderboardService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  @override
  Future<List<WeeklyLeaderboardEntry>> weeklyLeaderboard({
    required int weekOffset,
  }) async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const LeaderboardException(
        'Please sign in again to view the leaderboard.',
      );
    }

    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_weekly_learner_points',
        params: {'p_session_token': token, 'p_week_offset': weekOffset},
      );
      return rows
          .map(
            (row) => WeeklyLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.message.contains('Invalid or expired session')) {
        throw const LeaderboardException(
          'Your session has expired. Please log in again.',
        );
      }
      throw const LeaderboardException(
        'Weekly rankings could not be loaded. Please try again.',
      );
    } on FormatException {
      throw const LeaderboardException(
        'Weekly rankings could not be read. Please try again.',
      );
    } on TypeError {
      throw const LeaderboardException(
        'Weekly rankings could not be read. Please try again.',
      );
    }
  }
}
