import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/security/token_storage.dart';
import 'core/network/auth_http_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';

import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/home_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Preserve native splash until we explicitly remove it
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Load persisted theme first
  final themeCubit = await ThemeCubit.create();

  final tokenStorage = TokenStorage();
  const baseUrl = "http://192.168.29.66:4000";
  final authHttpClient = AuthHttpClient(tokenStorage: tokenStorage, baseUrl: baseUrl);
  final authRepository = AuthRepository(client: authHttpClient, tokenStorage: tokenStorage, baseUrl: baseUrl);

  // debug
  final a = await tokenStorage.readAccessToken();
  final r = await tokenStorage.readRefreshToken();
  print('DEBUG start: access=${a?.substring(0, a.length > 10 ? 10 : a.length)} refresh=${r?.substring(0, r.length > 10 ? 10 : r.length)}');

  runApp(
    MultiRepositoryProvider(
      providers: [RepositoryProvider.value(value: authRepository)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(repo: authRepository)..add(AppStarted())),
          BlocProvider<ThemeCubit>.value(value: themeCubit),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system &&
                WidgetsBinding.instance.window.platformBrightness == Brightness.dark);
        AppTheme.setSystemUIOverlayStyle(isDark: isDark);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'StreamSync',
          navigatorKey: appNavigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const AuthNavigator(),
        );
      },
    );
  }
}

/// Separate widget to handle auth-based navigation
class AuthNavigator extends StatelessWidget {
  const AuthNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        print('DEBUG AuthNavigator: listener triggered, status=${state.status}');
      },
      builder: (context, state) {
        print('DEBUG AuthNavigator: builder called, status=${state.status}');

        // Show splash while checking auth status
        if (state.status == AuthStatus.unknown) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Navigate based on authentication state
        if (state.isAuthenticated) {
          print('DEBUG AuthNavigator: Showing HomeScreen');
          return const HomeScreen();
        } else {
          print('DEBUG AuthNavigator: Showing LoginScreen');
          return LoginScreen(
            authRepository: context.read<AuthRepository>(),
          );
        }
      },
    );
  }
}