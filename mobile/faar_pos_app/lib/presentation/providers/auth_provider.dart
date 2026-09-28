import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../core/constants/api_constants.dart';
import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/talker_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

// Demo credentials for development / offline evaluation only
const _demoCredentials = [
  {'email': 'admin@faarpos.com', 'password': 'Admin@1234', 'role': 'org_admin', 'name': 'FAAR Admin'},
  {'email': 'cashier@faarpos.com', 'password': 'Cashier@1234', 'role': 'cashier', 'name': 'FAAR Cashier'},
];

SessionEntity _buildDemoSession(Map<String, dynamic> cred) {
  final role = cred['role'] as String;
  final user = UserEntity(
    id: role == 'org_admin' ? 1 : 2,
    orgId: 1,
    branchId: 1,
    email: cred['email'] as String,
    fullName: cred['name'] as String,
    role: role == 'org_admin' ? UserRole.orgAdmin : UserRole.cashier,
    isActive: true,
  );
  final branch = BranchEntity(
    id: 1,
    orgId: 1,
    name: 'FAAR Main Store',
    branchCode: 'MAIN',
    invoicePrefix: 'MAIN-',
    currencyCode: AppConfig.defaultCurrencyCode,
    currencySymbol: AppConfig.defaultCurrencySymbol,
    countryCode: AppConfig.defaultCountryCode,
    city: 'Kochi',
    isActive: true,
  );
  return SessionEntity(
    user: user,
    branch: branch,
    accessToken: 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
    refreshToken: 'demo_refresh_${DateTime.now().millisecondsSinceEpoch}',
    accessTokenExpiresAt: DateTime.now().add(AppConfig.accessTokenLifetime),
    refreshTokenExpiresAt: DateTime.now().add(AppConfig.refreshTokenLifetime),
  );
}

class AuthState {
  final UserEntity? user;
  final BranchEntity? branch;
  final bool isAuthenticated;
  final String? error;
  final bool isDemoMode;

  const AuthState({
    this.user,
    this.branch,
    this.isAuthenticated = false,
    this.error,
    this.isDemoMode = false,
  });

  AuthState copyWith({
    UserEntity? user,
    BranchEntity? branch,
    bool? isAuthenticated,
    Object? error = _sentinel,
    bool? isDemoMode,
  }) =>
      AuthState(
        user: user ?? this.user,
        branch: branch ?? this.branch,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        error: error == _sentinel ? this.error : error as String?,
        isDemoMode: isDemoMode ?? this.isDemoMode,
      );
}

const _sentinel = Object();

class AuthNotifier extends AsyncNotifier<AuthState> {
  SecureStorageService get _storage => ref.read(secureStorageProvider);

  @override
  Future<AuthState> build() async {
    final session = await _storage.loadSession();
    if (session != null) {
      return AuthState(
        user: session.user,
        branch: session.branch,
        isAuthenticated: true,
        isDemoMode: session.accessToken.startsWith('demo_token_'),
      );
    }
    return const AuthState(isAuthenticated: false);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // ── Try backend first ──────────────────────────────────────────
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.demoFallbackTimeout,
        receiveTimeout: AppConfig.demoFallbackTimeout,
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await dio.post(
        ApiConstants.login,
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final user = UserEntity.fromJson(data['user'] as Map<String, dynamic>);
      final branchData = data['branch'];
      final branch = branchData != null
          ? BranchEntity.fromJson(branchData as Map<String, dynamic>)
          : null;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;

      final session = SessionEntity(
        user: user,
        branch: branch,
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: DateTime.now().add(AppConfig.accessTokenLifetime),
        refreshTokenExpiresAt: DateTime.now().add(AppConfig.refreshTokenLifetime),
      );

      await _storage.saveSession(session);
      AppLog.info('User ${user.email} authenticated via backend');

      state = AsyncValue.data(AuthState(
        user: user,
        branch: branch,
        isAuthenticated: true,
        isDemoMode: false,
      ));
    } on DioException catch (e) {
      // ── Server unreachable → Fallback to demo mode if allowed in config ─
      final isNetworkError =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout;

      if (isNetworkError && AppConfig.allowDemoFallback) {
        final match = _demoCredentials.where((c) =>
          c['email'] == email.trim() && c['password'] == password
        ).firstOrNull;

        if (match != null) {
          final session = _buildDemoSession(match);
          await _storage.saveSession(session);
          AppLog.warning('User authenticated in OFFLINE DEMO MODE');

          state = AsyncValue.data(AuthState(
            user: session.user,
            branch: session.branch,
            isAuthenticated: true,
            isDemoMode: true,
          ));
          return;
        }

        state = const AsyncValue.data(AuthState(
          isAuthenticated: false,
          error: 'Backend offline. Development credentials:\nadmin@faarpos.com / Admin@1234',
        ));
      } else {
        final msg = e.response?.data?['detail']?.toString() ??
            'Invalid email or password. Please try again.';
        state = AsyncValue.data(AuthState(isAuthenticated: false, error: msg));
      }
    } catch (e, st) {
      AppLog.error('Authentication error', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
    state = const AsyncValue.data(AuthState(isAuthenticated: false));
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
