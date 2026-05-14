import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _accessToken != null;

  /// Base URL for API calls (dev: gateway on :8080)
  /// For web production, set SWIFTAI_API_URL or use relative /api/v1
  String get baseUrl {
    // Allow override via environment (not available in Flutter compile-time easily)
    // Default to absolute URL for dev, relative for prod build
    return 'http://localhost:8080/api/v1';
  }

  AuthService() {
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      _user = jsonDecode(userData);
    }
    notifyListeners();
  }

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    if (user != null) {
      await prefs.setString(_userKey, jsonEncode(user));
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  /// Login with email and password
  Future<AuthResult> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];

        await _saveTokens(
          accessToken: _accessToken!,
          refreshToken: _refreshToken!,
          user: _user,
        );

        _isLoading = false;
        notifyListeners();
        return AuthResult.success();
      } else {
        _isLoading = false;
        notifyListeners();
        final msg = jsonDecode(response.body)['message'] ?? 'Login failed';
        return AuthResult.failure(msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return AuthResult.failure('Connection error: unable to reach server');
    }
  }

  /// Register a new company + admin account
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    required String companyName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'display_name': displayName,
          'company_name': companyName,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body)['data'];
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];

        await _saveTokens(
          accessToken: _accessToken!,
          refreshToken: _refreshToken!,
          user: _user,
        );

        _isLoading = false;
        notifyListeners();
        return AuthResult.success();
      } else {
        _isLoading = false;
        notifyListeners();
        final msg = jsonDecode(response.body)['message'] ?? 'Registration failed';
        return AuthResult.failure(msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return AuthResult.failure('Connection error: unable to reach server');
    }
  }

  /// Logout
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _clearTokens();
    notifyListeners();
  }
}

class AuthResult {
  final bool success;
  final String? message;

  AuthResult._({required this.success, this.message});

  factory AuthResult.success() => AuthResult._(success: true);
  factory AuthResult.failure(String message) => AuthResult._(success: false, message: message);
}
