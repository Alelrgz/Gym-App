import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

// --- Service singletons ---

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.read(storageServiceProvider);
  return ApiClient(storage: storage);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(storageServiceProvider);
  return AuthService(api: api, storage: storage);
});

// --- Auth state ---

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final ApiClient _apiClient;

  AuthNotifier({
    required AuthService authService,
    required ApiClient apiClient,
  })  : _authService = authService,
        _apiClient = apiClient,
        super(const AuthState()) {
    // Wire up 401 handler
    _apiClient.onUnauthorized = _handleUnauthorized;
    // Try restoring session on creation
    _restoreSession();
  }

  void _handleUnauthorized() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authService.restoreSession();
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  String _parseError(dynamic e, {bool isLogin = true}) {
    if (e is DioException) {
      // No network / server unreachable
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Impossibile connettersi al server. Verifica la connessione.';
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Il server non risponde. Riprova.';
      }

      final status = e.response?.statusCode;
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : null;

      if (status == 401) {
        return 'Username o password non validi';
      }
      if (status == 400) {
        if (detail != null && detail.toString().toLowerCase().contains('already')) {
          return 'Username o email già registrati';
        }
        if (detail != null && detail.toString().toLowerCase().contains('password')) {
          return 'La password non soddisfa i requisiti';
        }
        return detail?.toString() ?? (isLogin ? 'Credenziali non valide' : 'Dati non validi');
      }
      if (status == 403) {
        return 'Account in attesa di approvazione';
      }
      if (status == 422) {
        return 'Dati mancanti o non validi';
      }
      if (status != null && status >= 500) {
        return 'Errore del server. Riprova più tardi.';
      }

      return detail?.toString() ?? 'Errore di connessione';
    }
    return isLogin ? 'Errore durante il login' : 'Errore durante la registrazione';
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _authService.login(username, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      print('[AUTH] Login error: $e');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e, isLogin: true),
      );
    }
  }

  Future<void> register({
    required String username,
    required String password,
    String? email,
    String? gymCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _authService.register(
        username: username,
        password: password,
        email: email,
        gymCode: gymCode,
      );
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      print('[AUTH] Register error: $e');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e, isLogin: false),
      );
    }
  }

  /// Update the current user in state (e.g. to refresh gym list).
  void updateUser(User user) {
    state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  final apiClient = ref.read(apiClientProvider);
  return AuthNotifier(authService: authService, apiClient: apiClient);
});
