import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:frontend/core/services/awesome_notification_service.dart';
import 'package:frontend/features/notifications/models/app_notifications.dart';

import 'core/network/auth_http_client.dart';
import 'core/network/fcm_service.dart';
import 'core/security/token_storage.dart';
import 'core/security/fcm_token_security.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';

import 'features/auth/bloc/auth_bloc.dart';

import 'features/auth/repositories/auth_repository.dart';
import 'features/notifications/bloc/notification_bloc.dart';
import 'features/notifications/bloc/notification_event.dart';
import 'features/notifications/repositories/notifications_repositories.dart';

import 'features/auth/presentation/login_screen.dart';
import 'features/home/home_screen.dart';

import 'firebase_options.dart';

// navigator key for showing snackbars / navigation from FCM handlers
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Preserve native splash until we remove it explicitly (AuthBloc will remove)
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ Initialize Awesome Notifications
  await AwesomeNotificationService.initialize();

  // Load persisted theme before runApp
  final themeCubit = await ThemeCubit.create();

  // --- Setup DI instances (same as your previous wiring) ---
  final tokenStorage = TokenStorage();
  const baseUrl = "http://192.168.29.66:4000"; // change to your URL
  final authHttpClient = AuthHttpClient(tokenStorage: tokenStorage, baseUrl: baseUrl);
  final authRepository = AuthRepository(client: authHttpClient, tokenStorage: tokenStorage, baseUrl: baseUrl);

  final fcmTokenStorage = FcmTokenStorage();
  final fcmService = FcmService(client: authHttpClient, storage: fcmTokenStorage, baseUrl: baseUrl);

  final notificationsRepo = NotificationsRepository(client: authHttpClient, baseUrl: baseUrl);

  // Run the app
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: notificationsRepo),
        RepositoryProvider.value(value: fcmService), // ✅ Add FcmService
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(repo: authRepository, fcmService: fcmService, fcmTokenStorage: fcmTokenStorage)
              ..add(AppStarted()),
          ),
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider(
            create: (_) => NotificationsBloc(repo: notificationsRepo),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Subscribe to notification stream after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToNotifications();
      _subscribeToAuth();
    });
  }

  void _subscribeToNotifications() {
    _notificationSubscription = AwesomeNotificationService.onNotificationReceived.listen(
          (notification) {
        print('🔔 Received notification in app: ${notification.title}');

        // Get NotificationsBloc and add notification
        final bloc = context.read<NotificationsBloc>();
        bloc.add(NotificationsReceivedPush(notification));

        // Update badge count
        _updateBadgeCount();
      },
      onError: (error) {
        print('❌ Notification stream error: $error');
      },
    );
  }

  // ✅ Listen to auth state changes and register FCM token when logged in
  void _subscribeToAuth() {
    _authSubscription = context.read<AuthBloc>().stream.listen((authState) {
      print('🔐 Auth state changed: ${authState.status}');

      if (authState.status == AuthStatus.authenticated && authState.user != null) {
        print('✅ User authenticated, registering FCM token');
        _registerFcmToken(authState.user!.id);

        // Also load notifications
        context.read<NotificationsBloc>().add(const NotificationsRequested());
      }
    });

    // Also check current state immediately
    final currentAuthState = context.read<AuthBloc>().state;
    if (currentAuthState.status == AuthStatus.authenticated && currentAuthState.user != null) {
      print('✅ User already authenticated, registering FCM token');
      _registerFcmToken(currentAuthState.user!.id);
      context.read<NotificationsBloc>().add(const NotificationsRequested());
    }
  }

  // ✅ Register FCM token with backend
  Future<void> _registerFcmToken(String userId) async {
    try {
      print('🔑 Getting FCM token...');
      final fcmToken = await AwesomeNotificationService.getFcmToken();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        print('🔑 FCM Token obtained: ${fcmToken.substring(0, 20)}...');

        // Use your existing FcmService
        final fcmService = context.read<FcmService>();
        await fcmService.registerToken(
          userId: userId,
          token: fcmToken,
          platform: 'android', // or use Platform.isIOS ? 'ios' : 'android'
        );

        print('✅ FCM token registered successfully with backend');
      } else {
        print('❌ Failed to get FCM token - token is null or empty');
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }

  void _updateBadgeCount() async {
    final bloc = context.read<NotificationsBloc>();
    final unreadCount = bloc.state.unreadCount;
    await AwesomeNotificationService.setBadgeCount(unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
        AppTheme.setSystemUIOverlayStyle(isDark: isDark);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'StreamSync',
          navigatorKey: appNavigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routes: {
            '/': (_) => const AuthNavigatorWrapper(),
            '/notifications/detail': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
              final id = args != null ? args['id'] as String? : null;
              return Scaffold(
                appBar: AppBar(title: const Text('Notification')),
                body: Center(child: Text('Open notification id: $id')),
              );
            },
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _authSubscription?.cancel();
    AwesomeNotificationService.dispose();
    super.dispose();
  }
}

/// Small widget to pick initial screen based on AuthBloc
class AuthNavigatorWrapper extends StatelessWidget {
  const AuthNavigatorWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        print('DEBUG AuthNavigator: listener status=${state.status}');
      },
      builder: (context, state) {
        print('DEBUG AuthNavigator: builder status=${state.status}');
        if (state.status == AuthStatus.unknown) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state.isAuthenticated) {
          return const HomeScreen();
        } else {
          return LoginScreen(authRepository: context.read<AuthRepository>());
        }
      },
    );
  }
}