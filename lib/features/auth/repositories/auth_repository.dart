import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthSession {
  final String token;
  final String role;
  final String userId;
  
  AuthSession({required this.token, required this.role, this.userId = ''});
}

class AuthRepository {
  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _userIdKey = 'user_id';

  Future<void> saveSession(String token, String role, {String userId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role);
    if (userId.isNotEmpty) await prefs.setString(_userIdKey, userId);
  }

  Future<AuthSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final role = prefs.getString(_roleKey);
    final userId = prefs.getString(_userIdKey) ?? '';
    
    if (token != null && role != null) {
      return AuthSession(token: token, role: role, userId: userId);
    }
    return null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
  }
}
