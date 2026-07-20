import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/permission.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/team/bloc/team_list_bloc.dart';
import 'package:mobile/features/team/bloc/team_list_event.dart';
import 'package:mobile/features/team/bloc/team_list_state.dart';
import 'package:mobile/features/team/data/team_models.dart';
import 'package:mobile/features/team/data/team_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTeamRepository extends Mock implements TeamRepository {}

void main() {
  late MockTeamRepository repository;

  const testUser1 = TeamUser(
    id: 'user-1',
    companyId: 'company-1',
    fullName: 'Jane Doe',
    email: 'jane@example.com',
    role: Role.employee,
    status: UserStatus.active,
    isIdentityVerified: true,
  );

  const testUser2 = TeamUser(
    id: 'user-2',
    companyId: 'company-1',
    fullName: 'John Smith',
    email: 'john@example.com',
    role: Role.siteEngineer,
    status: UserStatus.inactive,
    isIdentityVerified: false,
  );

  const testUser3 = TeamUser(
    id: 'user-3',
    companyId: 'company-1',
    fullName: 'Amy Lee',
    email: 'amy@example.com',
    role: Role.employee,
    status: UserStatus.suspended,
    isIdentityVerified: true,
  );

  const apiFailure = ApiException(
    statusCode: 500,
    errorCode: 'internal_error',
    message: 'Something went wrong.',
  );

  setUpAll(() {
    registerFallbackValue(Role.employee);
  });

  setUp(() {
    repository = MockTeamRepository();
  });

  TeamListBloc buildBloc() => TeamListBloc(repository);

  group('TeamListStarted', () {
    blocTest<TeamListBloc, TeamListState>(
      'emits [loading, success] with the loaded page when the request '
      'succeeds',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenAnswer(
          (_) async => const UserPage(
            users: [testUser1, testUser2],
            meta: null,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListStarted()),
      expect: () => [
        const TeamListState(status: TeamListStatus.loading),
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1, testUser2],
          page: 1,
          // 2 < pageSize(20) so this page is treated as the last one.
          hasReachedMax: true,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).called(1);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'emits [loading, success] with an empty list and hasReachedMax true '
      'when there are no users',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenAnswer((_) async => const UserPage(users: [], meta: null));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListStarted()),
      expect: () => [
        const TeamListState(status: TeamListStatus.loading),
        const TeamListState(
          status: TeamListStatus.success,
          users: [],
          page: 1,
          hasReachedMax: true,
        ),
      ],
    );

    blocTest<TeamListBloc, TeamListState>(
      'emits [loading, failure] with the ApiException message when the '
      'request fails',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenThrow(apiFailure);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListStarted()),
      expect: () => [
        const TeamListState(status: TeamListStatus.loading),
        const TeamListState(
          status: TeamListStatus.failure,
          errorMessage: 'Something went wrong.',
        ),
      ],
    );

    blocTest<TeamListBloc, TeamListState>(
      'reports hasReachedMax false when a full page comes back (more pages '
      'may exist)',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenAnswer(
          (_) async => UserPage(
            users: List.generate(
              20,
              (i) => TeamUser(
                id: 'user-$i',
                companyId: 'company-1',
                fullName: 'User $i',
                role: Role.employee,
                status: UserStatus.active,
                isIdentityVerified: true,
              ),
            ),
            meta: null,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListStarted()),
      expect: () => [
        const TeamListState(status: TeamListStatus.loading),
        isA<TeamListState>()
            .having((s) => s.status, 'status', TeamListStatus.success)
            .having((s) => s.users.length, 'users.length', 20)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false),
      ],
    );
  });

  group('TeamListRefreshed', () {
    blocTest<TeamListBloc, TeamListState>(
      'reloads page 1 with the current filters',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1],
        page: 3,
        roleFilter: Role.siteEngineer,
        search: 'jan',
      ),
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: Role.siteEngineer,
            search: 'jan',
          ),
        ).thenAnswer(
          (_) async => const UserPage(users: [testUser2], meta: null),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListRefreshed()),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.loading,
          users: [testUser1],
          page: 3,
          roleFilter: Role.siteEngineer,
          search: 'jan',
        ),
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser2],
          page: 1,
          hasReachedMax: true,
          roleFilter: Role.siteEngineer,
          search: 'jan',
        ),
      ],
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: Role.siteEngineer,
            search: 'jan',
          ),
        ).called(1);
      },
    );
  });

  group('TeamListRoleFilterChanged', () {
    blocTest<TeamListBloc, TeamListState>(
      'reloads page 1 with the new server-side role filter applied',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: Role.hrAdmin,
            search: null,
          ),
        ).thenAnswer(
          (_) async => const UserPage(users: [testUser1], meta: null),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListRoleFilterChanged(Role.hrAdmin)),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.loading,
          roleFilter: Role.hrAdmin,
        ),
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1],
          page: 1,
          hasReachedMax: true,
          roleFilter: Role.hrAdmin,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: Role.hrAdmin,
            search: null,
          ),
        ).called(1);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'clears the role filter and reloads unfiltered when passed null',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1],
        roleFilter: Role.hrAdmin,
      ),
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenAnswer(
          (_) async => const UserPage(
            users: [testUser1, testUser2],
            meta: null,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListRoleFilterChanged(null)),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.loading,
          users: [testUser1],
        ),
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1, testUser2],
          page: 1,
          hasReachedMax: true,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).called(1);
      },
    );
  });

  group('TeamListStatusFilterChanged', () {
    blocTest<TeamListBloc, TeamListState>(
      'applies the client-side status filter without calling the '
      'repository',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1, testUser2, testUser3],
      ),
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const TeamListStatusFilterChanged(UserStatus.active)),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1, testUser2, testUser3],
          statusFilter: UserStatus.active,
        ),
      ],
      verify: (bloc) {
        // visibleUsers applies the filter on top of the full users list.
        expect(bloc.state.visibleUsers, [testUser1]);
        verifyNever(
          () => repository.listUsers(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            role: any(named: 'role'),
            search: any(named: 'search'),
          ),
        );
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'clears the status filter when passed null, so visibleUsers reverts '
      'to the full list',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1, testUser2],
        statusFilter: UserStatus.active,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListStatusFilterChanged(null)),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1, testUser2],
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.visibleUsers, [testUser1, testUser2]);
      },
    );
  });

  group('TeamListSearchChanged', () {
    blocTest<TeamListBloc, TeamListState>(
      'reloads page 1 with the new search term',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: 'jane',
          ),
        ).thenAnswer(
          (_) async => const UserPage(users: [testUser1], meta: null),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListSearchChanged('jane')),
      expect: () => [
        const TeamListState(status: TeamListStatus.loading, search: 'jane'),
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1],
          page: 1,
          hasReachedMax: true,
          search: 'jane',
        ),
      ],
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: 'jane',
          ),
        ).called(1);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'treats an empty search string as no filter (passes null to the '
      'repository)',
      setUp: () {
        when(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenAnswer(
          (_) async => const UserPage(users: [testUser1], meta: null),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListSearchChanged('')),
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 1,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).called(1);
      },
    );
  });

  group('TeamListNextPageRequested', () {
    blocTest<TeamListBloc, TeamListState>(
      'appends the next page to the existing users and advances the page '
      'number',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1],
        page: 1,
      ),
      setUp: () {
        when(
          () => repository.listUsers(
            page: 2,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenAnswer(
          (_) async => const UserPage(users: [testUser2], meta: null),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListNextPageRequested()),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1, testUser2],
          page: 2,
          hasReachedMax: true,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.listUsers(
            page: 2,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).called(1);
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'does nothing when hasReachedMax is already true',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1],
        page: 1,
        hasReachedMax: true,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListNextPageRequested()),
      expect: () => <TeamListState>[],
      verify: (_) {
        verifyNever(
          () => repository.listUsers(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            role: any(named: 'role'),
            search: any(named: 'search'),
          ),
        );
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'does nothing while a load is already in flight',
      seed: () => const TeamListState(
        status: TeamListStatus.loading,
        users: [testUser1],
        page: 1,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListNextPageRequested()),
      expect: () => <TeamListState>[],
      verify: (_) {
        verifyNever(
          () => repository.listUsers(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            role: any(named: 'role'),
            search: any(named: 'search'),
          ),
        );
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      // NOTE: unlike every other handler in this bloc, a failed next-page
      // request only sets errorMessage and leaves `status` as `success`
      // rather than transitioning to `failure` — this looks like it may be
      // an oversight (the UI likely branches on `status` to show an error
      // view, which would never trigger here) but the test documents the
      // current, actual behaviour rather than the presumed-intended one.
      'on failure sets errorMessage but leaves status as success',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1],
        page: 1,
      ),
      setUp: () {
        when(
          () => repository.listUsers(
            page: 2,
            pageSize: 20,
            role: null,
            search: null,
          ),
        ).thenThrow(apiFailure);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const TeamListNextPageRequested()),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1],
          page: 1,
          errorMessage: 'Something went wrong.',
        ),
      ],
    );
  });

  group('TeamListUserStatusToggled', () {
    blocTest<TeamListBloc, TeamListState>(
      'deactivates the user and replaces it in the list when activate is '
      'false',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1, testUser2],
      ),
      setUp: () {
        when(
          () => repository.deactivateUser('user-1'),
        ).thenAnswer(
          (_) async => const TeamUser(
            id: 'user-1',
            companyId: 'company-1',
            fullName: 'Jane Doe',
            email: 'jane@example.com',
            role: Role.employee,
            status: UserStatus.inactive,
            isIdentityVerified: true,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TeamListUserStatusToggled('user-1', activate: false),
      ),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1, testUser2],
          isMutating: true,
        ),
        const TeamListState(
          status: TeamListStatus.success,
          users: [
            TeamUser(
              id: 'user-1',
              companyId: 'company-1',
              fullName: 'Jane Doe',
              email: 'jane@example.com',
              role: Role.employee,
              status: UserStatus.inactive,
              isIdentityVerified: true,
            ),
            testUser2,
          ],
        ),
      ],
      verify: (_) {
        verify(() => repository.deactivateUser('user-1')).called(1);
        verifyNever(() => repository.activateUser(any()));
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'activates the user when activate is true',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser2],
      ),
      setUp: () {
        when(
          () => repository.activateUser('user-2'),
        ).thenAnswer(
          (_) async => const TeamUser(
            id: 'user-2',
            companyId: 'company-1',
            fullName: 'John Smith',
            email: 'john@example.com',
            role: Role.siteEngineer,
            status: UserStatus.active,
            isIdentityVerified: false,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TeamListUserStatusToggled('user-2', activate: true),
      ),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser2],
          isMutating: true,
        ),
        const TeamListState(
          status: TeamListStatus.success,
          users: [
            TeamUser(
              id: 'user-2',
              companyId: 'company-1',
              fullName: 'John Smith',
              email: 'john@example.com',
              role: Role.siteEngineer,
              status: UserStatus.active,
              isIdentityVerified: false,
            ),
          ],
        ),
      ],
      verify: (_) {
        verify(() => repository.activateUser('user-2')).called(1);
        verifyNever(() => repository.deactivateUser(any()));
      },
    );

    blocTest<TeamListBloc, TeamListState>(
      'clears isMutating and sets errorMessage without touching the list '
      'when the toggle fails',
      seed: () => const TeamListState(
        status: TeamListStatus.success,
        users: [testUser1],
      ),
      setUp: () {
        when(() => repository.deactivateUser('user-1')).thenThrow(apiFailure);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TeamListUserStatusToggled('user-1', activate: false),
      ),
      expect: () => [
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1],
          isMutating: true,
        ),
        const TeamListState(
          status: TeamListStatus.success,
          users: [testUser1],
          errorMessage: 'Something went wrong.',
        ),
      ],
    );
  });
}
