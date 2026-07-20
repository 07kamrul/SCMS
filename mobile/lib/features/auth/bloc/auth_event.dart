import 'package:equatable/equatable.dart';

/// Events consumed by [AuthBloc].
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once at app startup (from the splash page) to check whether a
/// stored session is still valid.
final class AuthSessionRequested extends AuthEvent {
  const AuthSessionRequested();
}

/// Fired when the user submits the login form.
final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.emailOrPhone,
    required this.isEmail,
    required this.password,
  });

  final String emailOrPhone;
  final bool isEmail;
  final String password;

  @override
  List<Object?> get props => [emailOrPhone, isEmail, password];
}

/// Fired when the user explicitly signs out.
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Fired by [ApiClient]'s `onSessionExpired` callback (wired at DI time)
/// when a silent token refresh fails and the session can no longer be
/// trusted.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
