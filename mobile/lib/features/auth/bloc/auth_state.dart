import 'package:equatable/equatable.dart';

import '../data/auth_models.dart';

/// States emitted by [AuthBloc].
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Before the startup session check has run.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A session check or login attempt is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A valid session exists for [user].
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserPublic user;

  @override
  List<Object?> get props => [user];
}

/// No valid session. [message] is set when the app forced a logout (e.g.
/// session expiry) and is `null` for a normal logout or a fresh app start.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated([this.message]);

  final String? message;

  @override
  List<Object?> get props => [message];
}

/// Transient state for a failed login attempt. The UI should observe this
/// via a `BlocListener` (e.g. to show a `SnackBar`) rather than treat it as
/// a state the app stays in — the bloc immediately follows it with
/// [AuthUnauthenticated].
final class AuthFailure extends AuthState {
  const AuthFailure(this.message, {this.isAccountLocked = false});

  final String message;
  final bool isAccountLocked;

  @override
  List<Object?> get props => [message, isAccountLocked];
}
