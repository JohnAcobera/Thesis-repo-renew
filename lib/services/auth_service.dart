import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.user, required this.sessionToken});

  final UserModel user;
  final String sessionToken;
}

class AuthService {
  AuthService({SupabaseClient? client, FlutterSecureStorage? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'custom_session_token';
  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      await _client.rpc<void>(
        'register_user',
        params: {
          'p_full_name': fullName.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_password': password,
          'p_role': role,
        },
      );
    } on PostgrestException catch (error) {
      throw AuthException(_messageFor(error));
    } on Exception {
      throw const AuthException('Unable to connect. Please try again.');
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'login_user',
        params: {'p_email': email.trim().toLowerCase(), 'p_password': password},
      );
      final result = AuthResult(
        user: UserModel.fromJson(response['user'] as Map<String, dynamic>),
        sessionToken: response['session_token'] as String,
      );
      await _storage.write(key: _sessionKey, value: result.sessionToken);
      return result;
    } on PostgrestException catch (error) {
      throw AuthException(_messageFor(error));
    } on AuthException {
      rethrow;
    } on Exception {
      throw const AuthException('Unable to connect. Please try again.');
    }
  }

  Future<UserModel?> restoreSession() async {
    final token = await _storage.read(key: _sessionKey);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'verify_session',
        params: {'p_session_token': token},
      );
      return UserModel.fromJson(response);
    } on PostgrestException {
      await _storage.delete(key: _sessionKey);
      return null;
    } on Exception {
      rethrow;
    }
  }

  Future<void> logout() async {
    final token = await _storage.read(key: _sessionKey);
    try {
      if (token != null && token.isNotEmpty) {
        await _client.rpc<void>(
          'logout_user',
          params: {'p_session_token': token},
        );
      }
    } finally {
      await _storage.delete(key: _sessionKey);
    }
  }

  String _messageFor(PostgrestException error) {
    if (error.message.contains('Invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (error.message.contains('Email is already registered')) {
      return 'An account with this email already exists.';
    }
    if (error.message.contains('role')) {
      return 'Please choose a valid account type.';
    }
    return 'Something went wrong. Please try again.';
  }
}
