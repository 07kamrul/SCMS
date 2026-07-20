import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/bloc/auth_event.dart';
import 'package:mobile/features/auth/bloc/auth_state.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  const testUser = UserPublic(
    id: 'user-1',
    companyId: 'company-1',
    fullName: 'Jane Doe',
    email: 'jane@example.com',
    role: Role.employee,
    status: UserStatus.active,
    isIdentityVerified: true,
  );

  const testTokens = TokenPair(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    tokenType: 'bearer',
    expiresIn: 3600,
  );

  const testLoginResponse = LoginResponse(user: testUser, tokens: testTokens);

  setUpAll(() {
    // Fallback values for any() matchers on named params, in case future
    // tests need them.
    registerFallbackValue(testUser);
  });

  setUp(() {
    authRepository = MockAuthRepository();
  });

  AuthBloc buildBloc() => AuthBloc(authRepository);

  group('AuthSessionRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when no session is stored',
      setUp: () {
        when(() => authRepository.hasSession()).thenAnswer((_) async => false);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
      verify: (_) {
        verify(() => authRepository.hasSession()).called(1);
        verifyNever(() => authRepository.fetchMe());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when the stored session is '
      'still valid',
      setUp: () {
        when(() => authRepository.hasSession()).thenAnswer((_) async => true);
        when(() => authRepository.fetchMe()).thenAnswer((_) async => testUser);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] with no message when the '
      'stored session has since expired (silent refresh already failed)',
      setUp: () {
        when(() => authRepository.hasSession()).thenAnswer((_) async => true);
        when(() => authRepository.fetchMe()).thenThrow(
          const ApiException(
            statusCode: 401,
            errorCode: 'token_expired',
            message: 'Token expired',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login with email',
      setUp: () {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => testLoginResponse);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          emailOrPhone: 'jane@example.com',
          isEmail: true,
          password: 'password123',
        ),
      ),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
      verify: (_) {
        verify(
          () => authRepository.login(
            email: 'jane@example.com',
            phone: null,
            password: 'password123',
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'calls login with phone (not email) when isEmail is false',
      setUp: () {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => testLoginResponse);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          emailOrPhone: '+15551234567',
          isEmail: false,
          password: 'password123',
        ),
      ),
      expect: () => [const AuthLoading(), const AuthAuthenticated(testUser)],
      verify: (_) {
        verify(
          () => authRepository.login(
            email: null,
            phone: '+15551234567',
            password: 'password123',
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure, AuthUnauthenticated] on bad '
      'credentials (not locked)',
      setUp: () {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 401,
            errorCode: 'invalid_credentials',
            message: 'Invalid email or password.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          emailOrPhone: 'jane@example.com',
          isEmail: true,
          password: 'wrong-password',
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(
          'Invalid email or password.',
          isAccountLocked: false,
        ),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure(locked), AuthUnauthenticated] when '
      'the account is locked',
      setUp: () {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 429,
            errorCode: 'account_locked',
            message: 'Account locked due to too many attempts.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          emailOrPhone: 'jane@example.com',
          isEmail: true,
          password: 'wrong-password',
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(
          'Too many failed attempts — try again in 15 minutes.',
          isAccountLocked: true,
        ),
        const AuthUnauthenticated(),
      ],
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] and calls logout() when it succeeds',
      setUp: () {
        when(() => authRepository.logout()).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [const AuthUnauthenticated()],
      verify: (_) {
        verify(() => authRepository.logout()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'still emits [AuthUnauthenticated] even if logout() resolves after an '
      'internal network failure (per AuthRepository.logout() never '
      'throwing)',
      setUp: () {
        // logout() itself never throws — it swallows network failures
        // internally — so the fake here just resolves normally.
        when(() => authRepository.logout()).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [const AuthUnauthenticated()],
    );
  });

  group('AuthSessionExpired', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] with the forced-logout message',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthSessionExpired()),
      expect: () => [
        const AuthUnauthenticated(
          'Your session expired — please log in again.',
        ),
      ],
    );
  });
}
