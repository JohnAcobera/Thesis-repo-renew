import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/admin_overview_service.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';

void main() {
  test('loads totals and recent updates from the admin overview RPC', () async {
    final client = _supabaseClient((request) async {
      expect(request.url.path, endsWith('/rpc/get_admin_overview'));
      expect(jsonDecode(request.body), {
        'p_session_token': 'admin-session-token',
      });
      return http.Response(
        jsonEncode({
          'student_count': 24,
          'instructor_count': 3,
          'classroom_count': 5,
          'recent_updates': [
            {
              'type': 'classroom',
              'title': 'Classroom created: Biology',
              'description': 'Science - Alex Teacher',
              'created_at': '2026-10-24T01:00:00Z',
            },
          ],
        }),
        200,
        request: request,
        headers: {'content-type': 'application/json', 'content-range': '0-0/1'},
      );
    });
    final service = AdminOverviewService(
      client: client,
      authService: _TestAuthService(client),
    );

    final overview = await service.load();

    expect(overview.studentCount, 24);
    expect(overview.instructorCount, 3);
    expect(overview.classroomCount, 5);
    expect(overview.recentUpdates, hasLength(1));
    expect(overview.recentUpdates.single.type, 'classroom');
    await client.dispose();
  });

  test('returns a clear error when the admin session is missing', () async {
    final client = _supabaseClient((_) async {
      fail('The overview RPC should not run without a session token.');
    });
    final service = AdminOverviewService(
      client: client,
      authService: _TestAuthService(client, token: null),
    );

    await expectLater(
      service.load(),
      throwsA(
        isA<AdminOverviewException>().having(
          (error) => error.message,
          'message',
          contains('session has expired'),
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
  _TestAuthService(SupabaseClient client, {this.token = 'admin-session-token'})
    : super(client: client);

  final String? token;

  @override
  Future<String?> getSessionToken() async => token;
}
