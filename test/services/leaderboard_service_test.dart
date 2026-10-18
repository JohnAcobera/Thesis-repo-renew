import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/leaderboard_service.dart';

void main() {
  test('does not expose PostgREST diagnostics to the caller', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'XX000',
          'message': 'Internal database endpoint diagnostic',
          'details': 'Private schema and query details',
          'hint': 'Internal remediation hint',
        }),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = LeaderboardService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.weeklyLeaderboard(weekOffset: 0),
      throwsA(
        isA<LeaderboardException>().having(
          (error) => error.message,
          'message',
          allOf(
            isNot(contains('Internal database endpoint diagnostic')),
            isNot(contains('Private schema and query details')),
            isNot(contains('Internal remediation hint')),
            isNot(contains('XX000')),
          ),
        ),
      ),
    );
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
