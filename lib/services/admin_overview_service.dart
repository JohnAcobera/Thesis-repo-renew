import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_overview.dart';
import 'auth_service.dart';

class AdminOverviewException implements Exception {
  const AdminOverviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminOverviewService {
  AdminOverviewService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService =
          authService ?? AuthService(sessionStorageKey: 'admin_session_token');

  final SupabaseClient _client;
  final AuthService _authService;

  Future<AdminOverview> load() async {
    late final String? token;
    try {
      token = await _authService.getSessionToken();
    } on Exception {
      throw const AdminOverviewException(
        'Unable to read your admin session. Please sign in again.',
      );
    }
    if (token == null || token.isEmpty) {
      throw const AdminOverviewException(
        'Your admin session has expired. Please sign in again.',
      );
    }

    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'get_admin_overview',
        params: {'p_session_token': token},
      );
      return AdminOverview.fromJson(response);
    } on PostgrestException {
      throw const AdminOverviewException(
        'The overview could not be loaded. Please try again.',
      );
    } on FormatException {
      throw const AdminOverviewException(
        'The overview data could not be read. Please try again.',
      );
    } on TypeError {
      throw const AdminOverviewException(
        'The overview data could not be read. Please try again.',
      );
    } on Exception {
      throw const AdminOverviewException(
        'Unable to connect to load the overview. Please try again.',
      );
    }
  }
}
