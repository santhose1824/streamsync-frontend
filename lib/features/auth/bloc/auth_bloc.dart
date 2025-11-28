import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../core/network/api_exception.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc({required AuthRepository repo})
      : _repo = repo,
        super(const AuthState.unknown()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedIn>(_onLoggedIn);
    on<LoggedOut>(_onLoggedOut);

    print('DEBUG AuthBloc: created with initial state ${state.status}');
  }

  Future<void> _onAppStarted(AppStarted e, Emitter<AuthState> emit) async {
    print('DEBUG AuthBloc: _onAppStarted START');
    try {
      // Quick check: do we have any tokens?
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

      // If access null but refresh exists, try manual refresh
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

      // Now attempt fetch profile
      final user = await _repo.fetchProfile();
      print('DEBUG AuthBloc: fetchProfile succeeded user=${user.email}');
      emit(AuthState.authenticated(user));
      print('DEBUG AuthBloc: emitted AuthState.authenticated');
      FlutterNativeSplash.remove();
      return;
    } catch (err, st) {
      print('DEBUG AuthBloc: _onAppStarted CATCH err=$err');
      print('DEBUG AuthBloc: Stack trace: $st');

      // Check if it's an authorization error
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
    emit(AuthState.authenticated(e.user));
    print('DEBUG AuthBloc: emitted AuthState.authenticated from _onLoggedIn, new status=${state.status}');
  }

  Future<void> _onLoggedOut(LoggedOut e, Emitter<AuthState> emit) async {
    print('DEBUG AuthBloc: _onLoggedOut START');
    try {
      await _repo.logout();
    } catch (err) {
      print('DEBUG AuthBloc: logout error (ignoring): $err');
    }
    emit(const AuthState.unauthenticated());
    print('DEBUG AuthBloc: emitted AuthState.unauthenticated from _onLoggedOut, new status=${state.status}');
  }
}