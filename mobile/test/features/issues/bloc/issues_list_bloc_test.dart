import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/network/envelope.dart';
import 'package:mobile/features/issues/bloc/issues_list_bloc.dart';
import 'package:mobile/features/issues/bloc/issues_list_event.dart';
import 'package:mobile/features/issues/bloc/issues_list_state.dart';
import 'package:mobile/features/issues/data/issue_models.dart';
import 'package:mobile/features/issues/data/issue_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockIssueRepository extends Mock implements IssueRepository {}

void main() {
  late MockIssueRepository repository;

  setUpAll(() {
    // Fallback values for named enum args used with `any(named: ...)`.
    registerFallbackValue(IssueStatus.open);
    registerFallbackValue(IssuePriority.medium);
    registerFallbackValue(IssueCategory.other);
  });

  setUp(() {
    repository = MockIssueRepository();
  });

  Issue buildIssue(String id) {
    return Issue(
      id: id,
      companyId: 'company-1',
      projectId: 'project-1',
      title: 'Issue $id',
      category: IssueCategory.workDelay,
      priority: IssuePriority.medium,
      status: IssueStatus.open,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  IssueListPage buildPage({
    required List<Issue> items,
    required int page,
    required int totalPages,
  }) {
    return IssueListPage(
      items: items,
      meta: PageMeta(
        total: items.length,
        page: page,
        pageSize: 20,
        totalPages: totalPages,
      ),
    );
  }

  void mockList(IssueListPage Function() page) {
    when(
      () => repository.list(
        projectId: any(named: 'projectId'),
        status: any(named: 'status'),
        priority: any(named: 'priority'),
        category: any(named: 'category'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => page());
  }

  group('IssuesListBloc', () {
    blocTest<IssuesListBloc, IssuesListState>(
      'emits [loading, success] with issues on IssuesListStarted',
      setUp: () {
        mockList(
          () => buildPage(
            items: [buildIssue('1'), buildIssue('2')],
            page: 1,
            totalPages: 3,
          ),
        );
      },
      build: () => IssuesListBloc(repository),
      act: (bloc) => bloc.add(const IssuesListStarted(projectId: 'project-1')),
      expect: () => [
        const IssuesListState(
          status: IssuesListStatus.loading,
          projectId: 'project-1',
        ),
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.success)
            .having((s) => s.issues.length, 'issues.length', 2)
            .having((s) => s.page, 'page', 1)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false),
      ],
      verify: (_) {
        verify(
          () => repository.list(
            projectId: 'project-1',
            status: null,
            priority: null,
            category: null,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'emits [loading, success] with empty list and hasReachedMax true '
      'when the project has no issues',
      setUp: () {
        mockList(() => buildPage(items: const [], page: 1, totalPages: 1));
      },
      build: () => IssuesListBloc(repository),
      act: (bloc) => bloc.add(const IssuesListStarted(projectId: 'project-1')),
      expect: () => [
        const IssuesListState(
          status: IssuesListStatus.loading,
          projectId: 'project-1',
        ),
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.success)
            .having((s) => s.issues, 'issues', isEmpty)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true),
      ],
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'emits [loading, failure] with the ApiException message on error',
      setUp: () {
        when(
          () => repository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            category: any(named: 'category'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'server_error',
            message: 'Something went wrong',
          ),
        );
      },
      build: () => IssuesListBloc(repository),
      act: (bloc) => bloc.add(const IssuesListStarted(projectId: 'project-1')),
      expect: () => [
        const IssuesListState(
          status: IssuesListStatus.loading,
          projectId: 'project-1',
        ),
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Something went wrong',
            ),
      ],
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'appends the next page and updates hasReachedMax on '
      'IssuesListNextPageRequested',
      setUp: () {
        when(
          () => repository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            category: any(named: 'category'),
            page: 2,
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async =>
              buildPage(items: [buildIssue('3')], page: 2, totalPages: 2),
        );
      },
      build: () => IssuesListBloc(repository),
      seed: () => IssuesListState(
        status: IssuesListStatus.success,
        issues: [buildIssue('1'), buildIssue('2')],
        page: 1,
        hasReachedMax: false,
        projectId: 'project-1',
      ),
      act: (bloc) => bloc.add(const IssuesListNextPageRequested()),
      expect: () => [
        isA<IssuesListState>().having(
          (s) => s.isLoadingMore,
          'isLoadingMore',
          true,
        ),
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.success)
            .having((s) => s.issues.length, 'issues.length', 3)
            .having((s) => s.page, 'page', 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'does nothing on IssuesListNextPageRequested when hasReachedMax is true',
      build: () => IssuesListBloc(repository),
      seed: () => IssuesListState(
        status: IssuesListStatus.success,
        issues: [buildIssue('1')],
        hasReachedMax: true,
      ),
      act: (bloc) => bloc.add(const IssuesListNextPageRequested()),
      expect: () => <IssuesListState>[],
      verify: (_) {
        verifyNever(
          () => repository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            category: any(named: 'category'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        );
      },
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'does nothing on IssuesListNextPageRequested when isLoadingMore is true',
      build: () => IssuesListBloc(repository),
      seed: () => IssuesListState(
        status: IssuesListStatus.success,
        issues: [buildIssue('1')],
        isLoadingMore: true,
      ),
      act: (bloc) => bloc.add(const IssuesListNextPageRequested()),
      expect: () => <IssuesListState>[],
      verify: (_) {
        verifyNever(
          () => repository.list(
            projectId: any(named: 'projectId'),
            status: any(named: 'status'),
            priority: any(named: 'priority'),
            category: any(named: 'category'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        );
      },
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'reloads page 1 with the new filter on IssuesListFilterChanged',
      setUp: () {
        mockList(
          () => buildPage(
            items: [buildIssue('4')],
            page: 1,
            totalPages: 1,
          ),
        );
      },
      build: () => IssuesListBloc(repository),
      seed: () => IssuesListState(
        status: IssuesListStatus.success,
        issues: [buildIssue('1'), buildIssue('2')],
        page: 2,
        projectId: 'project-1',
      ),
      act: (bloc) => bloc.add(
        const IssuesListFilterChanged(status: IssueStatus.resolved),
      ),
      expect: () => [
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.loading)
            .having((s) => s.statusFilter, 'statusFilter', IssueStatus.resolved),
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.success)
            .having((s) => s.issues.length, 'issues.length', 1)
            .having((s) => s.page, 'page', 1),
      ],
      verify: (_) {
        verify(
          () => repository.list(
            projectId: 'project-1',
            status: IssueStatus.resolved,
            priority: null,
            category: null,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<IssuesListBloc, IssuesListState>(
      'reloads page 1 on IssuesListRefreshed with the current filters',
      setUp: () {
        mockList(
          () => buildPage(items: [buildIssue('1')], page: 1, totalPages: 1),
        );
      },
      build: () => IssuesListBloc(repository),
      seed: () => IssuesListState(
        status: IssuesListStatus.success,
        issues: [buildIssue('1')],
        page: 1,
        projectId: 'project-1',
      ),
      act: (bloc) => bloc.add(const IssuesListRefreshed()),
      expect: () => [
        isA<IssuesListState>()
            .having((s) => s.status, 'status', IssuesListStatus.success)
            .having((s) => s.issues.length, 'issues.length', 1),
      ],
    );
  });
}
