import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:frontend/core/network/fcm_service.dart';
import 'package:frontend/core/security/fcm_token_security.dart';

import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../core/network/api_exception.dart';


part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final FcmService _fcmService;
  final FcmTokenStorage _fcmTokenStorage; // optional, if you need to read token locally

  AuthBloc({
    required AuthRepository repo,
    required FcmService fcmService,
    required FcmTokenStorage fcmTokenStorage,
  })  : _repo = repo,
        _fcmService = fcmService,
        _fcmTokenStorage = fcmTokenStorage,
        super(const AuthState.unknown()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedIn>(_onLoggedIn);
    on<LoggedOut>(_onLoggedOut);

    // Listen for token rotation and re-register (fire-and-forget)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final currentState = state;
        if (currentState.status == AuthStatus.authenticated) {
          final user = (currentState as AuthState).user!;
          await _fcmService.registerToken(
            userId: user.id,
            token: newToken,
            platform: Platform.isAndroid ? 'android' : 'ios',
          );
        } else {
          // save locally so we can register when user logs in
          await _fcmTokenStorage.save(newToken);
        }
      } catch (err) {
        // don't crash the app over this, but log for debugging
        print('DEBUG FCM token refresh register failed: $err');
      }
    });

    print('DEBUG AuthBloc: created with initial state ${state.status}');
  }

  Future<void> _onAppStarted(AppStarted e, Emitter<AuthState> emit) async {
    print('DEBUG AuthBloc: _onAppStarted START');
    try {
      final hasAny = await _repo.hasAnyToken();
      print('DEBUG AuthBloc: tokens present? $hasAny');

      if (!hasAny) {
        print('DEBUG AuthBloc: no tokens -> emit unauthenticated');
        emit(const AuthState.unauthenticated());
        FlutterNativeSplash.remove();
        return;
      }

      final access = await _repo.readAccessToken();
      final refresh = await _repo.readRefreshToken();
      print('DEBUG AuthBloc: access=${access != null} refresh=${refresh != null}');

      if ((access == null || access.isEmpty) && (refresh != null && refresh.isNotEmpty)) {
        print('DEBUG AuthBloc: access missing but refresh exists -> attempting manualRefresh()');
        try {
          await _repo.manualRefresh();
          print('DEBUG AuthBloc: manualRefresh succeeded');
        } catch (err) {
          print('DEBUG AuthBloc: manualRefresh FAILED -> clearing tokens and unauthenticating. err=$err');
          await _repo.clearTokens();
          emit(const AuthState.unauthenticated());
          FlutterNativeSplash.remove();
          return;
        }
      }

      final user = await _repo.fetchProfile();
      print('DEBUG AuthBloc: fetchProfile succeeded user=${user.email}');

      // Register FCM token BEFORE emitting authenticated so app has token attached.
      await _tryRegisterFcmForUser(user);

      emit(AuthState.authenticated(user));
      print('DEBUG AuthBloc: emitted AuthState.authenticated');
      FlutterNativeSplash.remove();
      return;
    } catch (err, st) {
      print('DEBUG AuthBloc: _onAppStarted CATCH err=$err');
      print('DEBUG AuthBloc: Stack trace: $st');

      if (err is ApiException && err.statusCode == 401) {
        print('DEBUG AuthBloc: 401 error - clearing tokens');
        await _repo.clearTokens();
      }

      emit(const AuthState.unauthenticated());
      FlutterNativeSplash.remove();
    } finally {
      print('DEBUG AuthBloc: _onAppStarted END currentState=${state.status}');
    }
  }

  Future<void> _onLoggedIn(LoggedIn e, Emitter<AuthState> emit) async {
    print('DEBUG AuthBloc: _onLoggedIn for ${e.user.email}');
    // Register FCM token — if it fails, log and continue. We await so splash/flow can wait if desired.
    await _tryRegisterFcmForUser(e.user);
    emit(AuthState.authenticated(e.user));
    print('DEBUG AuthBloc: emitted AuthState.authenticated from _onLoggedIn, new status=${state.status}');
  }

  Future<void> _onLoggedOut(LoggedOut e, Emitter<AuthState> emit) async {
    print('DEBUG AuthBloc: _onLoggedOut START');
    try {
      // Get user id if available in current state
      String? userId;
      if (state.status == AuthStatus.authenticated) {
        final cur = state as AuthState;
        userId = cur.user?.id;
      } else {
        // if not authenticated, try to read stored user id from repository or skip
        userId = null;
      }

      if (userId != null) {
        // best-effort delete: this will clear local fcm storage too
        try {
          await _fcmService.deleteSavedTokenForUser(userId: userId);
        } catch (err) {
          print('DEBUG AuthBloc: failed to delete FCM token on logout: $err');
        }
      } else {
        // No userId — try to clear local saved token anyway
        try {
          await _fcmTokenStorage.clear();
        } catch (err) {
          print('DEBUG AuthBloc: failed to clear local fcm token store: $err');
        }
      }

      // logout via repo which clears tokens
      await _repo.logout();
    } catch (err) {
      print('DEBUG AuthBloc: logout error (ignoring): $err');
    }

    emit(const AuthState.unauthenticated());
    print('DEBUG AuthBloc: emitted AuthState.unauthenticated from _onLoggedOut, new status=${state.status}');
  }

  // --- Helpers ----------------------------------------------------------------

  Future<void> _tryRegisterFcmForUser(User user) async {
    try {
      // Prefer local saved token (maybe refreshed earlier) else get from Firebase
      String? token = await _fcmTokenStorage.read();
      if (token == null || token.isEmpty) {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (token == null || token.isEmpty) {
        print('DEBUG FCM: no token available to register for user ${user.id}');
        return;
      }

      await _fcmService.registerToken(
        userId: user.id,
        token: token,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );
      print('DEBUG FCM: registered token for user ${user.id}');
    } catch (err) {
      print('DEBUG FCM: registration failed for user ${user.id}: $err');
    }
  }
}
