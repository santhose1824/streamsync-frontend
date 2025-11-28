import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/presentation/profile_screen.dart';
import 'package:frontend/features/auth/repositories/auth_repository.dart';
import 'package:frontend/features/downloads/downloads.dart';
import 'package:frontend/features/notifications/bloc/notification_bloc.dart';
import 'package:frontend/features/notifications/bloc/notification_event.dart';
import 'package:frontend/features/notifications/presentation/notifications.dart';
import 'package:frontend/features/videos/video.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const _tabs = <Map<String, Object>>[
    {'label': 'Videos', 'icon': Icons.play_circle_outline, 'activeIcon': Icons.play_circle},
    {'label': 'Downloads', 'icon': Icons.download_outlined, 'activeIcon': Icons.download},
    {'label': 'Notifications', 'icon': Icons.notifications_outlined, 'activeIcon': Icons.notifications},
    {'label': 'Profile', 'icon': Icons.person_outline, 'activeIcon': Icons.person},
  ];

  @override
  void initState() {
    super.initState();
    // ✅ Load notifications when screen loads
    context.read<NotificationsBloc>().add(const NotificationsRequested());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final authRepo = RepositoryProvider.of<AuthRepository>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final indicatorWidth = (screenWidth - 32) / 4;

    // ✅ FIXED: Get unread notification count correctly
    final unreadCount = context.select(
          (NotificationsBloc bloc) => bloc.state.unreadCount,
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                },
                children: [
                  const Video(),
                  const Downloads(),
                  const Notifications(),
                  ProfileScreen(authRepository: authRepo),
                ],
              ),
            ),
          ],
        ),

        // Premium Professional Bottom Navigation with Badge
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101426) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF1F2433)
                    : const Color(0xFFE6E9F2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final isSelected = _currentIndex == index;
                  final isNotificationTab = index == 2; // Notifications tab

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _currentIndex = index);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      splashColor: (isDark
                          ? const Color(0xFF8B7FFF)
                          : const Color(0xFF6C63FF))
                          .withOpacity(0.1),
                      highlightColor: (isDark
                          ? const Color(0xFF8B7FFF)
                          : const Color(0xFF6C63FF))
                          .withOpacity(0.05),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon with badge (for notifications)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: isSelected ? 1.0 : 0.8,
                                    end: isSelected ? 1.0 : 0.8,
                                  ),
                                  duration: const Duration(milliseconds: 200),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark
                                              ? const Color(0xFF8B7FFF).withOpacity(0.15)
                                              : const Color(0xFF6C63FF).withOpacity(0.1))
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? (tab['activeIcon'] as IconData)
                                              : (tab['icon'] as IconData),
                                          size: 24,
                                          color: isSelected
                                              ? (isDark
                                              ? const Color(0xFF8B7FFF)
                                              : const Color(0xFF6C63FF))
                                              : (isDark
                                              ? const Color(0xFF98A0B3)
                                              : const Color(0xFF6B7280)),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // ✅ Badge for unread notifications
                                if (isNotificationTab && unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF101426) : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Center(
                                        child: Text(
                                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Label with color transition
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark
                                    ? const Color(0xFF8B7FFF)
                                    : const Color(0xFF6C63FF))
                                    : (isDark
                                    ? const Color(0xFF98A0B3)
                                    : const Color(0xFF6B7280)),
                                letterSpacing: 0.3,
                              ),
                              child: Text(
                                tab['label'] as String,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}