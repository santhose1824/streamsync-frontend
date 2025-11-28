import 'package:equatable/equatable.dart';
import 'package:frontend/features/notifications/models/app_notifications.dart';


enum NotificationsStatus { initial, loading, success, failure, sending }

class NotificationsState extends Equatable {
  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final String? error;

  const NotificationsState({
    required this.status,
    required this.notifications,
    this.error,
  });

  factory NotificationsState.initial() => const NotificationsState(status: NotificationsStatus.initial, notifications: []);

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    String? error,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      error: error,
    );
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [status, notifications, error];
}
