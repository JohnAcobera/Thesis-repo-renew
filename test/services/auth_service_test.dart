import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/auth_service.dart' as app_auth;

void main() {
  test(
    'admin login authenticates with a username instead of an email',
    () async {
      late http.Request capturedRequest;
      final client = _supabaseClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'code': 'P0001',
            'details': null,
            'hint': null,
            'message': 'Invalid username or password',
          }),
          400,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        app_auth.AuthService(
          client: client,
        ).loginAdmin(username: '  Admin.User ', password: 'secure-password'),
        throwsA(
          isA<app_auth.AuthException>().having(
            (error) => error.message,
            'message',
            'Invalid username or password.',
          ),
        ),
      );

      expect(capturedRequest.url.path, endsWith('/rpc/login_admin_user'));
      expect(jsonDecode(capturedRequest.body), {
        'p_username': 'admin.user',
        'p_password': 'secure-password',
      });
      await client.dispose();
    },
  );

  test('explains that a deactivated account cannot sign in', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'P0001',
          'details': null,
          'hint': null,
          'message': 'Account deactivated',
        }),
        400,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      app_auth.AuthService(
        client: client,
      ).login(email: 'student@example.com', password: 'secure-password'),
      throwsA(
        isA<app_auth.AuthException>().having(
          (error) => error.message,
          'message',
          'Your account has been deactivated. Contact an administrator for help.',
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
