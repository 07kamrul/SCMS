import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/notifications/bloc/notifications_list_bloc.dart';
import 'package:mobile/features/notifications/bloc/notifications_list_event.dart';
import 'package:mobile/features/notifications/bloc/notifications_list_state.dart';
import 'package:mobile/features/notifications/data/notification_models.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late MockNotificationRepository notificationRepository;

  final unreadNotification = AppNotification(
    id: 'notif-1',
    type: 'task.assigned',
    title: 'You were assigned a task',
    createdAt: DateTime.utc(2026, 7, 1),
  );

  final readNotification = AppNotification(
    id: 'notif-2',
    type: 'issue.created',
    title: 'New issue reported',
    readAt: DateTime.utc(2026, 7, 2),
    createdAt: DateTime.utc(2026, 6, 30),
  );

  setUp(() {
    notificationRepository = MockNotificationRepository();
  });

  NotificationsListBloc buildBloc() =>
      NotificationsListBloc(notificationRepository);

  group('NotificationsListSubscriptionRequested', () {
    blocTest<NotificationsListBloc, NotificationsListState>(
      'emits loading then loaded with the first page of notifications',
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => (
            [unreadNotification, readNotification],
            2,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const NotificationsListSubscriptionRequested()),
      expect: () => [
        const NotificationsListState(isLoading: true),
        NotificationsListState(
          notifications: [unreadNotification, readNotification],
          page: 1,
          total: 2,
          isLoading: false,
        ),
      ],
      verify: (_) {
        verify(
          () => notificationRepository.listMine(
            unreadOnly: false,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<NotificationsListBloc, NotificationsListState>(
      'starts with unreadOnly true when requested, and passes it through '
      'to the repository',
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([unreadNotification], 1));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const NotificationsListSubscriptionRequested(unreadOnly: true),
      ),
      expect: () => [
        const NotificationsListState(unreadOnly: true, isLoading: true),
        NotificationsListState(
          unreadOnly: true,
          notifications: [unreadNotification],
          page: 1,
          total: 1,
          isLoading: false,
        ),
      ],
      verify: (_) {
        verify(
          () => notificationRepository.listMine(
            unreadOnly: true,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<NotificationsListBloc, NotificationsListState>(
      'emits an empty, non-error loaded state when the repository returns '
      'no notifications',
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => (const <AppNotification>[], 0));
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const NotificationsListSubscriptionRequested()),
      expect: () => [
        const NotificationsListState(isLoading: true),
        const NotificationsListState(
          notifications: [],
          page: 1,
          total: 0,
          isLoading: false,
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.hasMore, isFalse);
      },
    );

    blocTest<NotificationsListBloc, NotificationsListState>(
      'emits [loading, failure] when the repository throws an ApiException',
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
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
          bloc.add(const NotificationsListSubscriptionRequested()),
      expect: () => [
        const NotificationsListState(isLoading: true),
        const NotificationsListState(
          isLoading: false,
          errorMessage: 'Something went wrong.',
        ),
      ],
    );
  });

  group('NotificationsListRefreshed', () {
    blocTest<NotificationsListBloc, NotificationsListState>(
      'reloads page 1 with the current filter, clearing any prior error',
      seed: () => const NotificationsListState(
        unreadOnly: true,
        errorMessage: 'stale error',
      ),
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([unreadNotification], 1));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const NotificationsListRefreshed()),
      expect: () => [
        const NotificationsListState(unreadOnly: true, isLoading: true),
        NotificationsListState(
          unreadOnly: true,
          notifications: [unreadNotification],
          page: 1,
          total: 1,
          isLoading: false,
        ),
      ],
      verify: (_) {
        verify(
          () => notificationRepository.listMine(
            unreadOnly: true,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );
  });

  group('NotificationsListNextPageRequested', () {
    blocTest<NotificationsListBloc, NotificationsListState>(
      'appends page 2 to the already-loaded notifications',
      seed: () => NotificationsListState(
        notifications: [unreadNotification],
        page: 1,
        total: 2,
      ),
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([readNotification], 2));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const NotificationsListNextPageRequested()),
      expect: () => [
        NotificationsListState(
          notifications: [unreadNotification],
          page: 1,
          total: 2,
          isLoadingMore: true,
        ),
        NotificationsListState(
          notifications: [unreadNotification, readNotification],
          page: 2,
          total: 2,
        ),
      ],
      verify: (_) {
        verify(
          () => notificationRepository.listMine(
            unreadOnly: false,
            page: 2,
            pageSize: 20,
          ),
        ).called(1);
      },
    );

    blocTest<NotificationsListBloc, NotificationsListState>(
      'does nothing when hasMore is false (already on the last page)',
      seed: () => NotificationsListState(
        notifications: [unreadNotification, readNotification],
        page: 1,
        total: 2,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const NotificationsListNextPageRequested()),
      expect: () => <NotificationsListState>[],
      verify: (_) {
        verifyNever(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        );
      },
    );

    blocTest<NotificationsListBloc, NotificationsListState>(
      'emits an error and stops loading-more when the repository throws',
      seed: () => NotificationsListState(
        notifications: [unreadNotification],
        page: 1,
        total: 2,
      ),
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 500,
            errorCode: 'server_error',
            message: 'Could not load more notifications.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const NotificationsListNextPageRequested()),
      expect: () => [
        NotificationsListState(
          notifications: [unreadNotification],
          page: 1,
          total: 2,
          isLoadingMore: true,
        ),
        NotificationsListState(
          notifications: [unreadNotification],
          page: 1,
          total: 2,
          isLoadingMore: false,
          errorMessage: 'Could not load more notifications.',
        ),
      ],
    );
  });

  group('NotificationsListUnreadOnlyToggled', () {
    blocTest<NotificationsListBloc, NotificationsListState>(
      'reloads page 1 with the new filter value',
      seed: () => NotificationsListState(
        notifications: [unreadNotification, readNotification],
        page: 1,
        total: 2,
      ),
      setUp: () {
        when(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer((_) async => ([unreadNotification], 1));
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const NotificationsListUnreadOnlyToggled(true)),
      expect: () => [
        NotificationsListState(
          unreadOnly: true,
          notifications: [unreadNotification, readNotification],
          page: 1,
          total: 2,
          isLoading: true,
        ),
        NotificationsListState(
          unreadOnly: true,
          notifications: [unreadNotification],
          page: 1,
          total: 1,
          isLoading: false,
        ),
      ],
      verify: (_) {
        verify(
          () => notificationRepository.listMine(
            unreadOnly: true,
            page: 1,
            pageSize: 20,
          ),
        ).called(1);
      },
    );
  });

  group('NotificationsListMarkReadRequested', () {
    blocTest<NotificationsListBloc, NotificationsListState>(
      'patches only the matching item in-place, without refetching the '
      'whole list',
      seed: () => NotificationsListState(
        notifications: [unreadNotification, readNotification],
        page: 1,
        total: 2,
      ),
      setUp: () {
        when(
          () => notificationRepository.markRead(unreadNotification.id),
        ).thenAnswer(
          (_) async => AppNotification(
            id: unreadNotification.id,
            type: unreadNotification.type,
            title: unreadNotification.title,
            readAt: DateTime.utc(2026, 7, 19),
            createdAt: unreadNotification.createdAt,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        NotificationsListMarkReadRequested(unreadNotification.id),
      ),
      verify: (bloc) {
        final notifications = bloc.state.notifications;
        expect(notifications.length, 2);

        final patched = notifications.firstWhere(
          (n) => n.id == unreadNotification.id,
        );
        expect(patched.readAt, DateTime.utc(2026, 7, 19));
        expect(patched.isUnread, isFalse);

        // The other item must be untouched.
        final untouched = notifications.firstWhere(
          (n) => n.id == readNotification.id,
        );
        expect(untouched.readAt, readNotification.readAt);

        // Marking read must not trigger a full list refetch.
        verifyNever(
          () => notificationRepository.listMine(
            unreadOnly: any(named: 'unreadOnly'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        );
        verify(
          () => notificationRepository.markRead(unreadNotification.id),
        ).called(1);
      },
    );

    blocTest<NotificationsListBloc, NotificationsListState>(
      'emits an error and leaves the list unchanged when markRead fails',
      seed: () => NotificationsListState(
        notifications: [unreadNotification],
        page: 1,
        total: 1,
      ),
      setUp: () {
        when(
          () => notificationRepository.markRead(unreadNotification.id),
        ).thenThrow(
          const ApiException(
            statusCode: 404,
            errorCode: 'not_found',
            message: 'Notification not found.',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        NotificationsListMarkReadRequested(unreadNotification.id),
      ),
      expect: () => [
        NotificationsListState(
          notifications: [unreadNotification],
          page: 1,
          total: 1,
          errorMessage: 'Notification not found.',
        ),
      ],
    );
  });
}
