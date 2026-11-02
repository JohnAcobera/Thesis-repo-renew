import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/admin_management_service.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';

void main() {
  test('loads admin directories and audit events', () async {
    final client = _supabaseClient((request) async {
      expect(request.url.path, endsWith('/rpc/get_admin_management_data'));
      expect(jsonDecode(request.body), {
        'p_session_token': 'admin-session-token',
      });
      return _jsonResponse({
        'teachers': [
          {
            'id': 12,
            'full_name': 'Alex Teacher',
            'email': 'alex@example.com',
            'created_at': '2026-10-24T01:00:00Z',
            'is_active': true,
            'classroom_count': 2,
          },
        ],
        'students': [],
        'classrooms': [],
        'activity': [
          {
            'id': 1,
            'action': 'Created teacher account',
            'target_label': 'Alex Teacher (alex@example.com)',
            'admin_name': 'Admin',
            'created_at': '2026-10-24T01:00:00Z',
          },
        ],
      }, request: request);
    });
    final service = _service(client);

    final data = await service.load();

    expect(data.teachers.single.fullName, 'Alex Teacher');
    expect(data.teachers.single.classroomCount, 2);
    expect(data.activity.single.action, 'Created teacher account');
    await client.dispose();
  });

  test(
    'sends teacher creation and account access changes to admin RPCs',
    () async {
      final requests = <http.Request>[];
      final client = _supabaseClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/rpc/create_admin_teacher')) {
          return _jsonResponse({'id': 12}, request: request);
        }
        return http.Response(
          'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = _service(client);

      await service.createTeacher(
        fullName: '  Alex Teacher ',
        email: ' Alex@Example.com ',
        password: 'secure-password',
      );
      await service.updateUser(
        userId: 12,
        fullName: 'Alex Teacher',
        email: 'alex@example.com',
        password: '',
      );
      await service.setUserActive(userId: 12, isActive: false);

      expect(
        requests.map((request) => request.url.path),
        orderedEquals([
          endsWith('/rpc/create_admin_teacher'),
          endsWith('/rpc/update_admin_user'),
          endsWith('/rpc/set_admin_user_active'),
        ]),
      );
      expect(jsonDecode(requests[0].body), {
        'p_session_token': 'admin-session-token',
        'p_full_name': 'Alex Teacher',
        'p_email': 'alex@example.com',
        'p_password': 'secure-password',
      });
      expect(jsonDecode(requests[1].body), {
        'p_session_token': 'admin-session-token',
        'p_user_id': 12,
        'p_full_name': 'Alex Teacher',
        'p_email': 'alex@example.com',
        'p_password': null,
      });
      expect(jsonDecode(requests[2].body), {
        'p_session_token': 'admin-session-token',
        'p_user_id': 12,
        'p_is_active': false,
      });
      await client.dispose();
    },
  );

  test('does not call the admin RPC when session token is missing', () async {
    final client = _supabaseClient((_) async {
      fail('The admin RPC should not run without an admin session token.');
    });
    final service = _service(client, token: null);

    await expectLater(
      service.load(),
      throwsA(
        isA<AdminManagementException>().having(
          (error) => error.message,
          'message',
          contains('session has expired'),
        ),
      ),
    );
    await client.dispose();
  });
}

AdminManagementService _service(
  SupabaseClient client, {
  String? token = 'admin-session-token',
}) => AdminManagementService(
  client: client,
  authService: _TestAuthService(client, token: token),
);

SupabaseClient _supabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) => SupabaseClient(
  'https://example.supabase.co',
  'test-anon-key',
  httpClient: MockClient(handler),
);

http.Response _jsonResponse(Object body, {required http.Request request}) =>
    http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json', 'content-range': '0-0/1'},
    );

class _TestAuthService extends AuthService {
  _TestAuthService(SupabaseClient client, {this.token = 'admin-session-token'})
    : super(client: client);

  final String? token;

  @override
  Future<String?> getSessionToken() async => token;
}
