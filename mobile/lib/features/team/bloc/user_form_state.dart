import 'package:equatable/equatable.dart';

import '../data/team_models.dart';

enum UserFormStatus { initial, loading, submitting, success, failure }

/// State for [UserFormBloc]. [loadedUser] is populated after
/// [UserFormUserLoaded] (edit mode) so the form page can pre-fill its
/// controllers; it stays null for a fresh create.
class UserFormState extends Equatable {
  const UserFormState({
    this.status = UserFormStatus.initial,
    this.loadedUser,
    this.savedUser,
    this.errorMessage,
  });

  final UserFormStatus status;
  final TeamUser? loadedUser;
  final TeamUser? savedUser;
  final String? errorMessage;

  UserFormState copyWith({
    UserFormStatus? status,
    TeamUser? loadedUser,
    TeamUser? savedUser,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserFormState(
      status: status ?? this.status,
      loadedUser: loadedUser ?? this.loadedUser,
      savedUser: savedUser ?? this.savedUser,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, loadedUser, savedUser, errorMessage];
}
