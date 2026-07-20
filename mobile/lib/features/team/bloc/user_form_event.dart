import 'package:equatable/equatable.dart';
import 'package:mobile/core/auth/permission.dart';

/// Events consumed by [UserFormBloc].
sealed class UserFormEvent extends Equatable {
  const UserFormEvent();

  @override
  List<Object?> get props => [];
}

/// Loads an existing user's details for the edit form. Never fired when
/// creating a new user.
final class UserFormUserLoaded extends UserFormEvent {
  const UserFormUserLoaded(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

/// Fired when the form is submitted, for both create and edit. `userId ==
/// null` means create; otherwise the existing user is updated.
final class UserFormSubmitted extends UserFormEvent {
  const UserFormSubmitted({
    this.userId,
    required this.fullName,
    this.email,
    this.phone,
    this.password,
    required this.role,
    this.jobTitle,
  });

  final String? userId;
  final String fullName;
  final String? email;
  final String? phone;

  /// Required on create, ignored on edit (the backend has no "change
  /// password via update" path — see `PasswordResetByAdmin`/reset-password).
  final String? password;

  final Role role;
  final String? jobTitle;

  @override
  List<Object?> get props => [
    userId,
    fullName,
    email,
    phone,
    password,
    role,
    jobTitle,
  ];
}
