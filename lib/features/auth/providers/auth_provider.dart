import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../models/user_model.dart';
import '../repositories/auth_repository.dart';

// ── Role Enum ──────────────────────────────────────────────────────────

enum UserRole { admin, teacher, parent, student, accountant }

final userRoleProvider = StateProvider<UserRole>((ref) => UserRole.admin);

// ── Auth State ─────────────────────────────────────────────────────────

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

// ── Auth Notifier ──────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final role = data['role'];
        
        await ref.read(authRepositoryProvider).saveSession(token, role);

        // Set the global role provider so MainLayout switches dashboards
        ref.read(userRoleProvider.notifier).state =
            UserRole.values.firstWhere((e) => e.name == role, orElse: () => UserRole.student);

        final user = UserModel(
          id: 'remote_verified_user',
          name: 'Authorized Account',
          email: email,
          phone: '',
          role: role,
          createdAt: DateTime.now(),
          deviceId: 'cloud_auth',
        );

        state = state.copyWith(user: user, isLoading: false, isAuthenticated: true);
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Login Framework Error');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).clearSession();
    state = const AuthState();
  }
}

// ── Provider ───────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
