import 'package:equatable/equatable.dart';
import 'package:frontend/features/notifications/models/app_notifications.dart';


abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();
  @override
  List<Object?> get props => [];
}

class NotificationsRequested extends NotificationsEvent {
  final bool force;
  const NotificationsRequested({this.force = false});
}

class NotificationsRefreshed extends NotificationsEvent {}

class NotificationDeleted extends NotificationsEvent {
  final String id;
  const NotificationDeleted(this.id);
  @override
  List<Object?> get props => [id];
}

class NotificationMarkedRead extends NotificationsEvent {
  final String id;
  const NotificationMarkedRead(this.id);
  @override
  List<Object?> get props => [id];
}

class NotificationsReceivedPush extends NotificationsEvent {
  final AppNotification notification;
  const NotificationsReceivedPush(this.notification);
  @override
  List<Object?> get props => [notification];
}

class SendTestNotificationRequested extends NotificationsEvent {
  final String title;
  final String body;
  final String? idempotencyKey;
  const SendTestNotificationRequested({required this.title, required this.body, this.idempotencyKey});
  @override
  List<Object?> get props => [title, body, idempotencyKey];
}
