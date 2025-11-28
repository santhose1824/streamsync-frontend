// auth_state.dart
part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;

  const AuthState._({required this.status, this.user});
  const AuthState.unknown() : this._(status: AuthStatus.unknown);
  const AuthState.authenticated(User user)
      : this._(status: AuthStatus.authenticated, user: user);
  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get isUnknown => status == AuthStatus.unknown;

  @override
  List<Object?> get props => [status, user];
}
