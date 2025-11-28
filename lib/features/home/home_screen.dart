import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/presentation/profile_screen.dart';
import 'package:frontend/features/auth/repositories/auth_repository.dart';
import 'package:frontend/features/downloads/downloads.dart';
import 'package:frontend/features/notifications/notifications.dart';
import 'package:frontend/features/videos/video.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Titles and icons for the bottom nav
  static const _tabs = <Map<String, Object>>[
    {'label': 'Videos', 'icon': Icons.play_circle_outline, 'activeIcon': Icons.play_circle},
    {'label': 'Downloads', 'icon': Icons.download_outlined, 'activeIcon': Icons.download},
    {'label': 'Notifications', 'icon': Icons.notifications_outlined, 'activeIcon': Icons.notifications},
    {'label': 'Profile', 'icon': Icons.person_outline, 'activeIcon': Icons.person},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // If not on first tab, go back to first tab on back press
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _pageController.jumpToPage(0);
      return false; // don't pop app
    }
    return true; // allow app to close
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final authRepo = RepositoryProvider.of<AuthRepository>(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Column(
          children: [
            // Flexible page area
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

        // Modern Bottom navigation bar with gradient indicator
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final isSelected = _currentIndex == index;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _currentIndex = index);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [
                              const Color(0xFF667eea).withOpacity(0.15),
                              const Color(0xFF764ba2).withOpacity(0.15),
                            ],
                          )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? (tab['activeIcon'] as IconData)
                                  : (tab['icon'] as IconData),
                              color: isSelected
                                  ? const Color(0xFF667eea)
                                  : Colors.grey.shade600,
                              size: 26,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab['label'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF667eea)
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 4),
                              Container(
                                height: 3,
                                width: 20,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
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