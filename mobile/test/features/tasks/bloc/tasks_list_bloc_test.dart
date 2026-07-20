import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/tasks/bloc/tasks_list_bloc.dart';
import 'package:mobile/features/tasks/bloc/tasks_list_event.dart';
import 'package:mobile/features/tasks/bloc/tasks_list_state.dart';
import 'package:mobile/features/tasks/data/task_models.dart';
import 'package:mobile/features/tasks/data/task_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository taskRepository;

  Task buildTask(String id) {
    return Task(
      id: id,
      companyId: 'company-1',
      projectId: 'project-1',
      title: 'Task $id',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isOverdue: false,
    );
  }

  final task1 = buildTask('task-1');
  final task2 = buildTask('task-2');

  setUp(() {
    taskRepository = MockTaskRepository();
  });

  TasksListBloc buildBloc() => TasksListBloc(taskRepository);

  group('TasksListSubscriptionRequested', () {
    blocTest<TasksListBloc, TasksListState>(
      'emits [loading, loaded] with the fetched page on success',
      setUp: () {
        when(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([task1, task2], 2));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TasksListSubscriptionRequested(projectId: 'project-1'),
      ),
      expect: () => [
        const TasksListState(projectId: 'project-1', isLoading: true),
        TasksListState(
          projectId: 'project-1',
          isLoading: false,
          tasks: [task1, task2],
          page: 1,
          total: 2,
        ),
      ],
      verify: (_) {
        verify(
          () => taskRepository.list(
            projectId: 'project-1',
            status: null,
            priority: null,
            overdue: false,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<TasksListBloc, TasksListState>(
      'emits a loaded state with an empty list when there are no tasks',
      setUp: () {
        when(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => (const <Task>[], 0));
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const TasksListSubscriptionRequested(projectId: 'project-1')),
      expect: () => [
        const TasksListState(projectId: 'project-1', isLoading: true),
        const TasksListState(
          projectId: 'project-1',
          isLoading: false,
          tasks: [],
          page: 1,
          total: 0,
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.hasMore, isFalse);
      },
    );

    blocTest<TasksListBloc, TasksListState>(
      'emits [loading, error] when the repository throws an ApiException',
      setUp: () {
        when(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'server_error',
            message: 'Something went wrong.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const TasksListSubscriptionRequested(projectId: 'project-1')),
      expect: () => [
        const TasksListState(projectId: 'project-1', isLoading: true),
        const TasksListState(
          projectId: 'project-1',
          isLoading: false,
          errorMessage: 'Something went wrong.',
        ),
      ],
    );
  });

  group('TasksListNextPageRequested', () {
    blocTest<TasksListBloc, TasksListState>(
      'appends the next page and advances the page counter',
      setUp: () {
        when(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([task2], 2));
      },
      seed: () => TasksListState(
        tasks: [task1],
        page: 1,
        total: 2,
        isLoading: false,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const TasksListNextPageRequested()),
      expect: () => [
        TasksListState(
          tasks: [task1],
          page: 1,
          total: 2,
          isLoadingMore: true,
        ),
        TasksListState(
          tasks: [task1, task2],
          page: 2,
          total: 2,
          isLoadingMore: false,
        ),
      ],
      verify: (_) {
        verify(
          () => taskRepository.list(
            projectId: null,
            status: null,
            priority: null,
            overdue: false,
            page: 2,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<TasksListBloc, TasksListState>(
      'emits [loadingMore, error] when the next page fails to load',
      setUp: () {
        when(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'server_error',
            message: 'Failed to load more tasks.',
          ),
        );
      },
      seed: () => TasksListState(
        tasks: [task1],
        page: 1,
        total: 2,
        isLoading: false,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const TasksListNextPageRequested()),
      expect: () => [
        TasksListState(
          tasks: [task1],
          page: 1,
          total: 2,
          isLoadingMore: true,
        ),
        TasksListState(
          tasks: [task1],
          page: 1,
          total: 2,
          isLoadingMore: false,
          errorMessage: 'Failed to load more tasks.',
        ),
      ],
    );

    blocTest<TasksListBloc, TasksListState>(
      'does nothing when there is no more data to load (hasMore == false)',
      seed: () => TasksListState(tasks: [task1, task2], page: 1, total: 2),
      build: buildBloc,
      act: (bloc) => bloc.add(const TasksListNextPageRequested()),
      expect: () => <TasksListState>[],
      verify: (_) {
        verifyNever(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        );
      },
    );
  });

  group('TasksListStatusFilterChanged', () {
    blocTest<TasksListBloc, TasksListState>(
      'reloads page 1 filtered by the new status',
      setUp: () {
        when(
          () => taskRepository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            overdue: any(named: 'overdue'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([task1], 1));
      },
      seed: () => TasksListState(tasks: [task1, task2], page: 1, total: 2),
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const TasksListStatusFilterChanged(TaskStatus.blocked)),
      expect: () => [
        TasksListState(
          tasks: [task1, task2],
          page: 1,
          total: 2,
          statusFilter: TaskStatus.blocked,
          isLoading: true,
        ),
        TasksListState(
          tasks: [task1],
          page: 1,
          total: 1,
          statusFilter: TaskStatus.blocked,
          isLoading: false,
        ),
      ],
      verify: (_) {
        verify(
          () => taskRepository.list(
            projectId: null,
            status: TaskStatus.blocked,
            priority: null,
            overdue: false,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );
  });
}
