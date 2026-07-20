import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../data/team_repository.dart';
import 'user_form_event.dart';
import 'user_form_state.dart';

/// Creates or updates a single user (`POST /users` / `PATCH /users/{id}`).
class UserFormBloc extends Bloc<UserFormEvent, UserFormState> {
  UserFormBloc(this._repository) : super(const UserFormState()) {
    on<UserFormUserLoaded>(_onUserLoaded);
    on<UserFormSubmitted>(_onSubmitted);
  }

  final TeamRepository _repository;

  Future<void> _onUserLoaded(
    UserFormUserLoaded event,
    Emitter<UserFormState> emit,
  ) async {
    emit(state.copyWith(status: UserFormStatus.loading, clearError: true));
    try {
      final user = await _repository.getUser(event.userId);
      emit(state.copyWith(status: UserFormStatus.initial, loadedUser: user));
    } on ApiException catch (e) {
      emit(state.copyWith(status: UserFormStatus.failure, errorMessage: e.message));
    }
  }

  Future<void> _onSubmitted(
    UserFormSubmitted event,
    Emitter<UserFormState> emit,
  ) async {
    emit(state.copyWith(status: UserFormStatus.submitting, clearError: true));
    try {
      final userId = event.userId;
      final saved = userId == null
          ? await _repository.createUser(
              fullName: event.fullName,
              email: event.email,
              phone: event.phone,
              password: event.password!,
              role: event.role,
              jobTitle: event.jobTitle,
            )
          : await _repository.updateUser(
              userId,
              fullName: event.fullName,
              email: event.email,
              phone: event.phone,
              role: event.role,
              jobTitle: event.jobTitle,
            );
      emit(state.copyWith(status: UserFormStatus.success, savedUser: saved));
    } on ApiException catch (e) {
      emit(state.copyWith(status: UserFormStatus.failure, errorMessage: e.message));
    }
  }
}
