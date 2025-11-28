import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/services/awesome_notification_service.dart';
import 'package:frontend/features/notifications/bloc/notification_bloc.dart';
import 'package:frontend/features/notifications/bloc/notification_event.dart';
import 'package:frontend/features/notifications/bloc/notification_state.dart';
import 'package:frontend/features/notifications/presentation/notifications_detail.dart';


class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(const NotificationsRequested());
  }

  Future<void> _onRefresh() async {
    context.read<NotificationsBloc>().add(NotificationsRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        if (state.status == NotificationsStatus.loading && state.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading notifications...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        if (state.status == NotificationsStatus.failure && state.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final list = state.notifications;
        if (list.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_none,
                          size: 50,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'re all caught up!',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${list.where((n) => !n.isRead).length} unread',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            actions: [
              Tooltip(
                message: 'Mark all as read',
                child: IconButton(
                  icon: Icon(
                    Icons.done_all,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    final unreadIds = list.where((n) => !n.isRead).map((n) => n.id).toList();
                    if (unreadIds.isNotEmpty) {
                      for (final id in unreadIds) {
                        context.read<NotificationsBloc>().add(NotificationMarkedRead(id));
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('All notifications marked as read'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
              Tooltip(
                message: 'Refresh',
                child: IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _onRefresh,
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            color: Theme.of(context).colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final n = list[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      context.read<NotificationsBloc>().add(NotificationDeleted(n.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Notification deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              // You can add undo functionality here
                            },
                          ),
                        ),
                      );
                    },
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: n.isRead
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: n.isRead
                              ? Theme.of(context).dividerColor
                              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (!n.isRead)
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (!n.isRead) context.read<NotificationsBloc>().add(NotificationMarkedRead(n.id));
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NotificationDetailPage(notificationId: n.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!n.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 8, right: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  SizedBox(width: n.isRead ? 20 : 0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        n.body,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (!n.isRead)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'New',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}