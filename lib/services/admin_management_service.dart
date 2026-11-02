import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_management.dart';
import 'auth_service.dart';

class AdminManagementException implements Exception {
  const AdminManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminManagementService {
  AdminManagementService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService =
          authService ?? AuthService(sessionStorageKey: 'admin_session_token');

  final SupabaseClient _client;
  final AuthService _authService;

  Future<AdminManagementData> load() async {
    final token = await _sessionToken();
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'get_admin_management_data',
        params: {'p_session_token': token},
      );
      return AdminManagementData.fromJson(response);
    } on PostgrestException catch (error) {
      throw AdminManagementException(_messageFor(error));
    } on FormatException {
      throw const AdminManagementException(
        'The account and classroom data could not be read.',
      );
    } on TypeError {
      throw const AdminManagementException(
        'The account and classroom data could not be read.',
      );
    }
  }

  Future<void> createTeacher({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final token = await _sessionToken();
    try {
      await _client.rpc<Map<String, dynamic>>(
        'create_admin_teacher',
        params: {
          'p_session_token': token,
          'p_full_name': fullName.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_password': password,
        },
      );
    } on PostgrestException catch (error) {
      throw AdminManagementException(_messageFor(error));
    }
  }

  Future<void> updateUser({
    required int userId,
    required String fullName,
    required String email,
    String? password,
  }) async {
    final token = await _sessionToken();
    try {
      await _client.rpc<void>(
        'update_admin_user',
        params: {
          'p_session_token': token,
          'p_user_id': userId,
          'p_full_name': fullName.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_password': password == null || password.isEmpty ? null : password,
        },
      );
    } on PostgrestException catch (error) {
      throw AdminManagementException(_messageFor(error));
    }
  }

  Future<void> setUserActive({
    required int userId,
    required bool isActive,
  }) async {
    final token = await _sessionToken();
    try {
      await _client.rpc<void>(
        'set_admin_user_active',
        params: {
          'p_session_token': token,
          'p_user_id': userId,
          'p_is_active': isActive,
        },
      );
    } on PostgrestException catch (error) {
      throw AdminManagementException(_messageFor(error));
    }
  }

  Future<String> _sessionToken() async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const AdminManagementException(
        'Your admin session has expired. Please sign in again.',
      );
    }
    return token;
  }

  String _messageFor(PostgrestException error) {
    if (error.message.contains('Email is already registered')) {
      return 'An account with this email already exists.';
    }
    if (error.message.contains('Invalid teacher account details')) {
      return 'Enter a name, valid email, and password with at least 8 characters.';
    }
    if (error.message.contains('Invalid account details')) {
      return 'Enter a name and valid email. A new password must have at least 8 characters.';
    }
    if (error.message.contains('Invalid or expired admin session')) {
      return 'Your admin session has expired. Please sign in again.';
    }
    if (error.message.contains('Account not found')) {
      return 'That account could not be found. Refresh and try again.';
    }
    return 'The admin request could not be completed. Please try again.';
  }
}
