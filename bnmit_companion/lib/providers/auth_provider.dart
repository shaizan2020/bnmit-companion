import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/models/user.dart';
import 'package:bnmit_companion/services/auth_service.dart';
import 'package:bnmit_companion/services/storage_service.dart';

// Service providers
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(storageServiceProvider));
});

// Auth state
class AuthState {
  final User? user;
  final bool isAuthenticated;
  final String? error;

  const AuthState({this.user, this.isAuthenticated = false, this.error});

  AuthState copyWith({User? user, bool? isAuthenticated, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Try auto-login on app start
    final authService = ref.read(authServiceProvider);
    final storageService = ref.read(storageServiceProvider);

    final isLoggedIn = await storageService.isLoggedIn();
    if (!isLoggedIn) {
      return const AuthState();
    }

    try {
      final user = await authService.autoLogin();
      if (user != null) {
        return AuthState(user: user, isAuthenticated: true);
      }
    } catch (_) {
      // Auto-login failed
    }
    return const AuthState();
  }

  Future<void> login({
    required String username,
    required String dob,
    required int idType,
    required String verificationDigits,
    required String semester,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final user = await authService.login(
        username: username,
        dob: dob,
        idType: idType,
        verificationDigits: verificationDigits,
        semester: semester,
      );
      return AuthState(user: user, isAuthenticated: true);
    });
    state = result;
    if (result.hasError) {
      throw result.error!;
    }
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AsyncData(AuthState());
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
