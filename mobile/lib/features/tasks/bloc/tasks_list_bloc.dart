import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/task_repository.dart';
import 'tasks_list_event.dart';
import 'tasks_list_state.dart';

/// Loads, filters, and paginates the task list for a project (or across all
/// projects visible to the current user when `projectId` is null).
class TasksListBloc extends Bloc<TasksListEvent, TasksListState> {
  TasksListBloc(this._taskRepository) : super(const TasksListState()) {
    on<TasksListSubscriptionRequested>(_onSubscriptionRequested);
    on<TasksListRefreshed>(_onRefreshed);
    on<TasksListNextPageRequested>(_onNextPageRequested);
    on<TasksListStatusFilterChanged>(_onStatusFilterChanged);
    on<TasksListPriorityFilterChanged>(_onPriorityFilterChanged);
    on<TasksListOverdueFilterToggled>(_onOverdueFilterToggled);
  }

  final TaskRepository _taskRepository;

  Future<void> _onSubscriptionRequested(
    TasksListSubscriptionRequested event,
    Emitter<TasksListState> emit,
  ) async {
    emit(TasksListState(projectId: event.projectId, isLoading: true));
    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    TasksListRefreshed event,
    Emitter<TasksListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _loadFirstPage(emit);
  }

  Future<void> _onStatusFilterChanged(
    TasksListStatusFilterChanged event,
    Emitter<TasksListState> emit,
  ) async {
    emit(
      state.copyWith(
        statusFilter: event.status,
        isLoading: true,
        errorMessage: null,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onPriorityFilterChanged(
    TasksListPriorityFilterChanged event,
    Emitter<TasksListState> emit,
  ) async {
    emit(
      state.copyWith(
        priorityFilter: event.priority,
        isLoading: true,
        errorMessage: null,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onOverdueFilterToggled(
    TasksListOverdueFilterToggled event,
    Emitter<TasksListState> emit,
  ) async {
    emit(
      state.copyWith(
        overdueOnly: event.overdueOnly,
        isLoading: true,
        errorMessage: null,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onNextPageRequested(
    TasksListNextPageRequested event,
    Emitter<TasksListState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    final nextPage = state.page + 1;
    try {
      final (tasks, total) = await _taskRepository.list(
        projectId: state.projectId,
        status: state.statusFilter,
        priority: state.priorityFilter,
        overdue: state.overdueOnly,
        page: nextPage,
        pageSize: state.pageSize,
      );
      emit(
        state.copyWith(
          tasks: [...state.tasks, ...tasks],
          page: nextPage,
          total: total,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.message));
    }
  }

  Future<void> _loadFirstPage(Emitter<TasksListState> emit) async {
    try {
      final (tasks, total) = await _taskRepository.list(
        projectId: state.projectId,
        status: state.statusFilter,
        priority: state.priorityFilter,
        overdue: state.overdueOnly,
        page: 1,
        pageSize: state.pageSize,
      );
      emit(
        state.copyWith(
          tasks: tasks,
          page: 1,
          total: total,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    }
  }
}
