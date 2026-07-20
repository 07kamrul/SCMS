import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/projects/bloc/projects_list_bloc.dart';
import 'package:mobile/features/projects/bloc/projects_list_event.dart';
import 'package:mobile/features/projects/bloc/projects_list_state.dart';
import 'package:mobile/features/projects/data/project_models.dart';
import 'package:mobile/features/projects/data/project_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockProjectRepository projectRepository;

  final testProject = Project(
    id: 'project-1',
    companyId: 'company-1',
    name: 'Downtown Tower',
    description: 'A tall building',
    status: ProjectStatus.running,
    progressPercent: 42,
    boundary: null,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );

  setUp(() {
    projectRepository = MockProjectRepository();
  });

  ProjectsListBloc buildBloc() => ProjectsListBloc(projectRepository);

  group('ProjectsListRequested', () {
    blocTest<ProjectsListBloc, ProjectsListState>(
      'emits [loading, loaded] with projects on success',
      setUp: () {
        when(
          () => projectRepository.list(status: any(named: 'status')),
        ).thenAnswer((_) async => (projects: [testProject], total: 1));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectsListRequested()),
      expect: () => [
        const ProjectsListState(isLoading: true),
        ProjectsListState(projects: [testProject], isLoading: false),
      ],
      verify: (_) {
        verify(() => projectRepository.list(status: null)).called(1);
      },
    );

    blocTest<ProjectsListBloc, ProjectsListState>(
      'passes the requested status filter through to the repository',
      setUp: () {
        when(
          () => projectRepository.list(status: any(named: 'status')),
        ).thenAnswer((_) async => (projects: <Project>[], total: 0));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const ProjectsListRequested(status: ProjectStatus.completed),
      ),
      expect: () => [
        const ProjectsListState(isLoading: true),
        const ProjectsListState(projects: [], isLoading: false),
      ],
      verify: (_) {
        verify(
          () => projectRepository.list(status: ProjectStatus.completed),
        ).called(1);
      },
    );

    blocTest<ProjectsListBloc, ProjectsListState>(
      'emits [loading, loaded-empty] when the repository returns no '
      'projects',
      setUp: () {
        when(
          () => projectRepository.list(status: any(named: 'status')),
        ).thenAnswer((_) async => (projects: <Project>[], total: 0));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectsListRequested()),
      expect: () => [
        const ProjectsListState(isLoading: true),
        const ProjectsListState(projects: [], isLoading: false),
      ],
    );

    blocTest<ProjectsListBloc, ProjectsListState>(
      'emits [loading, error] and keeps prior projects when the repository '
      'throws an ApiException',
      setUp: () {
        when(
          () => projectRepository.list(status: any(named: 'status')),
        ).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'internal_error',
            message: 'Something went wrong.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectsListRequested()),
      expect: () => [
        const ProjectsListState(isLoading: true),
        const ProjectsListState(
          isLoading: false,
          error: 'Something went wrong.',
        ),
      ],
    );

    blocTest<ProjectsListBloc, ProjectsListState>(
      'keeps previously loaded projects visible while a re-fetch fails',
      seed: () => ProjectsListState(projects: [testProject], isLoading: false),
      setUp: () {
        when(
          () => projectRepository.list(status: any(named: 'status')),
        ).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'internal_error',
            message: 'Something went wrong.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectsListRequested()),
      expect: () => [
        ProjectsListState(projects: [testProject], isLoading: true),
        ProjectsListState(
          projects: [testProject],
          isLoading: false,
          error: 'Something went wrong.',
        ),
      ],
    );
  });
}
