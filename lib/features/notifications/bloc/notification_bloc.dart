import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/services/awesome_notification_service.dart';
import 'package:frontend/features/notifications/bloc/notification_event.dart';
import 'package:frontend/features/notifications/bloc/notification_state.dart';
import 'package:frontend/features/notifications/repositories/notifications_repositories.dart';


class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRepository _repo;

  NotificationsBloc({required NotificationsRepository repo})
      : _repo = repo,
        super(NotificationsState.initial()) {
    on<NotificationsRequested>(_onRequested);
    on<NotificationsRefreshed>(_onRefreshed);
    on<NotificationDeleted>(_onDeleted);
    on<NotificationMarkedRead>(_onMarkedRead);
    on<NotificationsReceivedPush>(_onReceivedPush);
    on<SendTestNotificationRequested>(_onSendTest);
  }

  Future<void> _onRequested(NotificationsRequested event, Emitter<NotificationsState> emit) async {
    if (state.status == NotificationsStatus.loading && !event.force) return;
    emit(state.copyWith(status: NotificationsStatus.loading, error: null));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: NotificationsStatus.success, notifications: list));
    } on ApiException catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, error: e.message));
    } catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRefreshed(NotificationsRefreshed event, Emitter<NotificationsState> emit) async {
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: NotificationsStatus.success, notifications: list));
    } on ApiException catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, error: e.message));
    } catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onDeleted(NotificationDeleted event, Emitter<NotificationsState> emit) async {
    final before = state.notifications;
    // optimistic update
    emit(state.copyWith(notifications: before.where((n) => n.id != event.id).toList()));
    try {
      await _repo.delete(event.id);
    } on ApiException catch (e) {
      // revert on failure
      emit(state.copyWith(notifications: before, status: NotificationsStatus.failure, error: e.message));
    } catch (e) {
      emit(state.copyWith(notifications: before, status: NotificationsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onMarkedRead(NotificationMarkedRead event, Emitter<NotificationsState> emit) async {
    final before = state.notifications;
    final updated = before.map((n) => n.id == event.id ? n.copyWith(isRead: true) : n).toList();
    emit(state.copyWith(notifications: updated));

    // ✅ Update badge count
    await AwesomeNotificationService.setBadgeCount(state.unreadCount);

    try {
      await _repo.markRead([event.id]);
    } on ApiException catch (e) {
      emit(state.copyWith(notifications: before, status: NotificationsStatus.failure, error: e.message));
    } catch (e) {
      emit(state.copyWith(notifications: before, status: NotificationsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onReceivedPush(NotificationsReceivedPush event, Emitter<NotificationsState> emit) async {
    // Prepend new notification
    final updated = [event.notification, ...state.notifications];
    emit(state.copyWith(notifications: updated));
  }

  Future<void> _onSendTest(SendTestNotificationRequested event, Emitter<NotificationsState> emit) async {
    emit(state.copyWith(status: NotificationsStatus.sending));
    try {
      final resp = await _repo.sendTest(title: event.title, body: event.body, idempotencyKey: event.idempotencyKey);
      // optionally refresh list
      final list = await _repo.list();
      emit(state.copyWith(status: NotificationsStatus.success, notifications: list));
      // You could also expose a success side-effect; the UI will react if necessary
    } on ApiException catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, error: e.message));
    } catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, error: e.toString()));
    }
  }
}
