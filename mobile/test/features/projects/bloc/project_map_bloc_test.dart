import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/projects/bloc/project_map_bloc.dart';
import 'package:mobile/features/projects/bloc/project_map_event.dart';
import 'package:mobile/features/projects/bloc/project_map_state.dart';
import 'package:mobile/features/projects/data/project_models.dart';
import 'package:mobile/features/projects/data/project_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockProjectRepository projectRepository;

  // [lng, lat] ring — GeoJSON convention. lng and lat are deliberately far
  // apart in magnitude so a silent identity-mapped swap is easy to catch.
  const testBoundary = GeoJsonPolygon([
    [10.0, 50.0],
    [11.0, 50.0],
    [11.0, 51.0],
    [10.0, 50.0],
  ]);

  final testProject = Project(
    id: 'project-1',
    companyId: 'company-1',
    name: 'Downtown Tower',
    description: 'A tall building',
    status: ProjectStatus.running,
    progressPercent: 42,
    boundary: testBoundary,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );

  setUp(() {
    projectRepository = MockProjectRepository();
  });

  ProjectMapBloc buildBloc() => ProjectMapBloc(projectRepository);

  group('ProjectMapRequested', () {
    blocTest<ProjectMapBloc, ProjectMapState>(
      'emits [loading, loaded] with projects on success',
      setUp: () {
        when(
          () => projectRepository.listForMap(),
        ).thenAnswer((_) async => [testProject]);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectMapRequested()),
      expect: () => [
        const ProjectMapState(isLoading: true),
        ProjectMapState(projects: [testProject], isLoading: false),
      ],
      verify: (_) {
        verify(() => projectRepository.listForMap()).called(1);
      },
    );

    blocTest<ProjectMapBloc, ProjectMapState>(
      'emits [loading, loaded-empty] when the repository returns no '
      'projects',
      setUp: () {
        when(
          () => projectRepository.listForMap(),
        ).thenAnswer((_) async => <Project>[]);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectMapRequested()),
      expect: () => [
        const ProjectMapState(isLoading: true),
        const ProjectMapState(projects: [], isLoading: false),
      ],
    );

    blocTest<ProjectMapBloc, ProjectMapState>(
      'emits [loading, error] and keeps prior projects when the repository '
      'throws an ApiException',
      setUp: () {
        when(() => projectRepository.listForMap()).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'internal_error',
            message: 'Something went wrong.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectMapRequested()),
      expect: () => [
        const ProjectMapState(isLoading: true),
        const ProjectMapState(
          isLoading: false,
          error: 'Something went wrong.',
        ),
      ],
    );

    blocTest<ProjectMapBloc, ProjectMapState>(
      'keeps previously loaded projects visible while a re-fetch fails',
      seed: () => ProjectMapState(projects: [testProject], isLoading: false),
      setUp: () {
        when(() => projectRepository.listForMap()).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'internal_error',
            message: 'Something went wrong.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ProjectMapRequested()),
      expect: () => [
        ProjectMapState(projects: [testProject], isLoading: true),
        ProjectMapState(
          projects: [testProject],
          isLoading: false,
          error: 'Something went wrong.',
        ),
      ],
    );
  });

  group('GeoJsonPolygon coordinate swap (regression guard)', () {
    test(
      'toLatLngRing() swaps [lng, lat] GeoJSON order to LatLng(lat, lng) — '
      'not an identity mapping',
      () {
        final latLngs = testBoundary.toLatLngRing();

        expect(latLngs, hasLength(testBoundary.ring.length));
        for (var i = 0; i < latLngs.length; i++) {
          final position = testBoundary.ring[i];
          final latLng = latLngs[i];
          // GeoJSON position is [lng, lat]; LatLng is (lat, lng).
          expect(latLng.latitude, position[1]);
          expect(latLng.longitude, position[0]);
          // Since lng != lat for every point here, a bloc/model bug that
          // forgot the swap (or swapped twice) would fail these asserts.
          expect(latLng.latitude, isNot(position[0]));
          expect(latLng.longitude, isNot(position[1]));
        }

        final expected = [
          const LatLng(50.0, 10.0),
          const LatLng(50.0, 11.0),
          const LatLng(51.0, 11.0),
          const LatLng(50.0, 10.0),
        ];
        for (var i = 0; i < expected.length; i++) {
          expect(latLngs[i].latitude, expected[i].latitude);
          expect(latLngs[i].longitude, expected[i].longitude);
        }
      },
    );

    test(
      'fromLatLngRing() swaps back to [lng, lat] and closes an open ring',
      () {
        final drawnPoints = [
          const LatLng(50.0, 10.0),
          const LatLng(50.0, 11.0),
          const LatLng(51.0, 11.0),
        ];

        final polygon = GeoJsonPolygon.fromLatLngRing(drawnPoints);

        expect(polygon.ring, [
          [10.0, 50.0],
          [11.0, 50.0],
          [11.0, 51.0],
          [10.0, 50.0],
        ]);
        // Ring must be closed: first == last.
        expect(polygon.ring.first, polygon.ring.last);
      },
    );

    test(
      'toLatLngRing() followed by fromLatLngRing() round-trips a closed ring',
      () {
        final roundTripped = GeoJsonPolygon.fromLatLngRing(
          testBoundary.toLatLngRing(),
        );

        expect(roundTripped.ring, testBoundary.ring);
      },
    );
  });
}
