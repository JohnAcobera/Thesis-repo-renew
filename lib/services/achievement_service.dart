import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/achievement_badge.dart';
import 'auth_service.dart';

abstract interface class AchievementRepository {
  Future<Set<String>> earnedBadges();
}

class AchievementService implements AchievementRepository {
  AchievementService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  @override
  Future<Set<String>> earnedBadges() async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const AchievementServiceException(
        'Your session has expired. Please log in again.',
      );
    }

    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_student_achievement_badges',
        params: {'p_session_token': token},
      );
      final earned = <String>{};
      for (final row in rows) {
        final badgeRow = Map<String, dynamic>.from(row as Map);
        final badge = badgeRow['badge_id'];
        if (badge is! String ||
            !AchievementBadge.all.any((item) => item.id == badge)) {
          throw const FormatException('An achievement badge was invalid.');
        }
        if (!badgeRow.containsKey('earned_at')) {
          throw const FormatException('An achievement badge was invalid.');
        }
        final earnedAt = badgeRow['earned_at'];
        if (earnedAt != null) {
          if (earnedAt is! String) {
            throw const FormatException('An achievement badge was invalid.');
          }
          DateTime.parse(earnedAt);
          earned.add(badge);
        }
      }
      return earned;
    } on PostgrestException catch (error) {
      throw AchievementServiceException(_databaseMessage(error));
    } on FormatException {
      throw const AchievementServiceException(
        'Your achievements could not be read. Please try again.',
      );
    } on TypeError {
      throw const AchievementServiceException(
        'Your achievements could not be read. Please try again.',
      );
    }
  }

  Future<AchievementCapture<T>> captureNewBadges<T>(
    Future<T> Function() saveActivity,
  ) async {
    Set<String>? earnedBefore;
    String? errorMessage;
    try {
      earnedBefore = await earnedBadges();
    } on AchievementServiceException catch (error) {
      errorMessage = error.message;
    } on Exception {
      errorMessage = 'New badges could not be checked. Please try again.';
    }

    final result = await saveActivity();
    if (earnedBefore == null) {
      return AchievementCapture(value: result, errorMessage: errorMessage);
    }

    try {
      final earnedAfter = await earnedBadges();
      return AchievementCapture(
        value: result,
        newlyEarnedBadgeIds: earnedAfter.difference(earnedBefore),
      );
    } on AchievementServiceException catch (error) {
      return AchievementCapture(value: result, errorMessage: error.message);
    } on Exception {
      return AchievementCapture(
        value: result,
        errorMessage: 'New badges could not be checked. Please try again.',
      );
    }
  }

  String _databaseMessage(PostgrestException error) {
    if (error.message.contains('Invalid or expired session')) {
      return 'Your session has expired. Please log in again.';
    }
    if (error.code == 'PGRST202' || error.code == '42883') {
      return 'Achievement badges are not configured. Run '
          'supabase/achievement_badges.sql in the Supabase SQL Editor, then '
          'try again.';
    }
    final code = error.code;
    return code == null
        ? 'Your achievements could not be loaded. Please try again.'
        : 'Your achievements could not be loaded (Supabase error $code). '
              'Please try again.';
  }
}

class AchievementCapture<T> {
  const AchievementCapture({
    required this.value,
    this.newlyEarnedBadgeIds = const {},
    this.errorMessage,
  });

  final T value;
  final Set<String> newlyEarnedBadgeIds;
  final String? errorMessage;
}

class AchievementNotificationQueue {
  static final Map<String, Set<String>> _pendingBadges = {};

  static void add(String email, Iterable<String> badgeIds) {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return;
    _pendingBadges.putIfAbsent(key, () => <String>{}).addAll(badgeIds);
  }

  static List<AchievementBadge> take(String email) {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final pending = _pendingBadges.remove(key) ?? const <String>{};
    return AchievementBadge.all
        .where((badge) => pending.contains(badge.id))
        .toList(growable: false);
  }

  static void clear() => _pendingBadges.clear();
}

class AchievementServiceException implements Exception {
  const AchievementServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
