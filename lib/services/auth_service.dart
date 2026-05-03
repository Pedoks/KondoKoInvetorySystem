import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService {
  // ── Persist token to disk ─────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }
  
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  static Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.userKey);
    if (raw == null) return null;
    return UserModel.fromJson(jsonDecode(raw));
  }

  static Future<void> deleteUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
  }

  // ── Register ──────────────────────────────────────────
  Future<AuthResult> register({
    required String firstName,
    required String surname,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          'surname':   surname,
          'email':     email,
          'password':  password,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(body);
        await saveToken(user.token);
        await saveUser(user);
        return AuthResult(success: true, user: user);
      }

      final message = body['message'] as String? ?? 'Registration failed.';
      return AuthResult(success: false, errorMessage: message);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Cannot connect to server. Check your connection.',
      );
    }
  }

  // ── Login ─────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    email,
          'password': password,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(body);
        await saveToken(user.token);
        await saveUser(user);
        return AuthResult(success: true, user: user);
      }

      final message = body['message'] as String? ?? 'Login failed.';
      return AuthResult(success: false, errorMessage: message);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Cannot connect to server. Check your connection.',
      );
    }
  }

  // ── Logout ────────────────────────────────────────────
  Future<void> logout() async {
    await deleteToken();
    await deleteUser();
  }
}

// ── Result wrapper ─────────────────────────────────────
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;

  AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
  });
}