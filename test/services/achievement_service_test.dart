import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/achievement_service.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';

void main() {
  test('only returns badges with an earned timestamp', () async {
    late http.Request capturedRequest;
    final client = _supabaseClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode([
          {'badge_id': 'FirstStep', 'earned_at': '2026-11-17T00:00:00Z'},
          {'badge_id': 'QuizRookie', 'earned_at': '2026-11-17T00:00:00Z'},
          {'badge_id': 'Podium', 'earned_at': null},
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AchievementService(
      client: client,
      authService: _TestAuthService(client),
    );

    expect(await service.earnedBadges(), {'FirstStep', 'QuizRookie'});
    expect(
      capturedRequest.url.path,
      endsWith('/rpc/get_student_achievement_badges'),
    );
    expect(jsonDecode(capturedRequest.body), {'p_session_token': 's' * 40});
    await client.dispose();
  });

  test('does not expose PostgREST diagnostics', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'XX000',
          'message': 'Internal database endpoint diagnostic',
          'details': 'Private schema details',
          'hint': 'Internal remediation hint',
        }),
        500,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AchievementService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.earnedBadges(),
      throwsA(
        isA<AchievementServiceException>().having(
          (error) => error.message,
          'message',
          'Your achievements could not be loaded (Supabase error XX000). '
              'Please try again.',
        ),
      ),
    );
    await client.dispose();
  });

  test('explains when the achievement RPC is not installed', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'PGRST202',
          'message': 'Function not found.',
          'details': null,
          'hint': null,
        }),
        404,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AchievementService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.earnedBadges(),
      throwsA(
        isA<AchievementServiceException>().having(
          (error) => error.message,
          'message',
          contains('Run supabase/achievement_badges.sql'),
        ),
      ),
    );
    await client.dispose();
  });

  test('rejects unknown badge ids', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode([
          {'badge_id': 'UnexpectedBadge', 'earned_at': null},
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AchievementService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.earnedBadges(),
      throwsA(
        isA<AchievementServiceException>().having(
          (error) => error.message,
          'message',
          'Your achievements could not be read. Please try again.',
        ),
      ),
    );
    await client.dispose();
  });

  test('queues only badges newly earned after an activity is saved', () async {
    AchievementNotificationQueue.clear();
    var requestCount = 0;
    final client = _supabaseClient((request) async {
      requestCount++;
      return http.Response(
        jsonEncode(
          requestCount == 1
              ? [
                  {'badge_id': 'FirstStep', 'earned_at': null},
                  {'badge_id': 'QuizRookie', 'earned_at': null},
                ]
              : [
                  {
                    'badge_id': 'FirstStep',
                    'earned_at': '2026-11-17T00:00:00Z',
                  },
                  {'badge_id': 'QuizRookie', 'earned_at': null},
                ],
        ),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AchievementService(
      client: client,
      authService: _TestAuthService(client),
    );

    final capture = await service.captureNewBadges(() async => 'saved');
    AchievementNotificationQueue.add(
      'Student@Example.com',
      capture.newlyEarnedBadgeIds,
    );

    expect(capture.value, 'saved');
    expect(capture.newlyEarnedBadgeIds, {'FirstStep'});
    expect(
      AchievementNotificationQueue.take(
        'student@example.com',
      ).map((badge) => badge.id),
      ['FirstStep'],
    );
    expect(AchievementNotificationQueue.take('student@example.com'), isEmpty);
    await client.dispose();
  });

  test('badge lookup failure does not prevent saving the activity', () async {
    var activitySaved = false;
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'XX000',
          'message': 'Internal database endpoint diagnostic',
          'details': null,
          'hint': null,
        }),
        500,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AchievementService(
      client: client,
      authService: _TestAuthService(client),
    );

    final capture = await service.captureNewBadges(() async {
      activitySaved = true;
      return 'saved';
    });

    expect(activitySaved, isTrue);
    expect(capture.value, 'saved');
    expect(capture.errorMessage, contains('Supabase error XX000'));
    await client.dispose();
  });
}

SupabaseClient _supabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) => SupabaseClient(
  'https://example.supabase.co',
  'test-anon-key',
  httpClient: MockClient(handler),
);

class _TestAuthService extends AuthService {
  _TestAuthService(SupabaseClient client) : super(client: client);

  @override
  Future<String?> getSessionToken() async => 's' * 40;
}
