import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../auth/models/user.dart';
import '../../../core/security/token_storage.dart';

class AuthRepository {
  final http.Client _client;
  final TokenStorage _tokenStorage;
  final String _baseUrl;

  AuthRepository({
    required http.Client client,
    required TokenStorage tokenStorage,
    required String baseUrl,
  })  : _client = client,
        _tokenStorage = tokenStorage,
        _baseUrl = baseUrl;


  /// ----- Token helpers (public) -----
  Future<String?> readAccessToken() => _tokenStorage.readAccessToken();
  Future<String?> readRefreshToken() => _tokenStorage.readRefreshToken();
  Future<void> clearTokens() => _tokenStorage.clear();

  /// Convenience: whether any token exists (useful on app start)
  Future<bool> hasAnyToken() async {
    final a = await _tokenStorage.readAccessToken();
    final r = await _tokenStorage.readRefreshToken();
    return (a != null && a.isNotEmpty) || (r != null && r.isNotEmpty);
  }


  Future<bool> hasRefreshToken() async {
    final r = await _tokenStorage.readRefreshToken();
    return r != null && r.isNotEmpty;
  }


  // Helper to parse error body (best-effort)
  String _parseErrorMessage(http.Response res) {
    try {
      final body = json.decode(res.body);
      if (body is Map<String, dynamic>) {
        if (body.containsKey('message') && body['message'] is String) {
          return body['message'] as String;
        }
        // Typical validation error payloads may contain `errors` or `fieldErrors`
        if (body.containsKey('errors') && body['errors'] is Map) {
          final Map m = body['errors'] as Map;
          // join first field errors into readable string
          final parts = <String>[];
          m.forEach((k, v) {
            if (v is List && v.isNotEmpty) {
              parts.add('$k: ${v.first}');
            } else if (v is String) {
              parts.add('$k: $v');
            }
          });
          if (parts.isNotEmpty) return parts.join('. ');
        }
        // fallback try first string field
        final firstString = body.values.firstWhere((v) => v is String, orElse: () => null);
        if (firstString != null) return firstString as String;
      }
    } catch (_) {
      // ignore parse errors
    }
    return 'Server returned ${res.statusCode}';
  }

  Future<User> register({required String name, required String email, required String password}) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    http.Response res;
    try {
      res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Unexpected network error');
    }

    if (res.statusCode == 201) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final userJson = body['user'] as Map<String, dynamic>;
      final access = body['accessToken'] as String;
      final refresh = body['refreshToken'] as String;
      await _tokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
      return User.fromJson(userJson);
    }

    // Non-201 -> throw ApiException with parsed message
    final message = _parseErrorMessage(res);
    throw ApiException(message, statusCode: res.statusCode, details: {
      'body': res.body,
    });
  }

  Future<User> login({required String email, required String password}) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    http.Response res;
    try {
      res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Unexpected network error');
    }

    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final userJson = body['user'] as Map<String, dynamic>;
      final access = body['accessToken'] as String;
      final refresh = body['refreshToken'] as String;
      await _tokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
      return User.fromJson(userJson);
    }

    final message = _parseErrorMessage(res);
    throw ApiException(message, statusCode: res.statusCode, details: {'body': res.body});
  }
  Future<void> logout() async {
    final refresh = await _tokenStorage.readRefreshToken();
    if (refresh == null) {
      await _tokenStorage.clear();
      return;
    }
    final res = await _client.post(
      Uri.parse('$_baseUrl/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refreshToken': refresh}),
    );
    // Regardless of server response, clear local tokens
    await _tokenStorage.clear();
    if (res.statusCode != 200 && res.statusCode != 204) {
      // swallow error but log if needed
    }
  }

  Future<User> fetchProfile() async {
    final res = await _client.get(Uri.parse('$_baseUrl/me'));
    if (res.statusCode == 401) {
      throw ApiException('Unauthorized', statusCode: 401, details: {'body': res.body});
    }
    if (res.statusCode != 200) {
      throw ApiException('Fetch profile failed', statusCode: res.statusCode, details: {'body': res.body});
    }

    // Parse and be tolerant of shapes:
    try {
      final decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic>) {
        // Case A: { "user": { ... } }
        if (decoded.containsKey('user') && decoded['user'] is Map<String, dynamic>) {
          return User.fromJson(decoded['user'] as Map<String, dynamic>);
        }
        // Case B: { id: ..., name: ... } (user object directly)
        return User.fromJson(decoded);
      }
      throw ApiException('Invalid profile payload', statusCode: res.statusCode, details: {'body': res.body});
    } catch (e) {
      // JSON parse error or cast error
      throw ApiException('Failed to parse profile', statusCode: res.statusCode, details: {'body': res.body, 'error': e.toString()});
    }
  }



  /// Update profile: PATCH /me
  Future<User> updateProfile({ required String name, String? email }) async {
    final uri = Uri.parse('$_baseUrl/me');
    http.Response res;
    try {
      final payload = <String, dynamic>{'name': name};
      // debug
      // print('PATCH $uri -> $payload');

      res = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }

    // debug
    print('updateProfile status=${res.statusCode} body=${res.body}');

    if (res.statusCode == 200) {
      // Try to parse returned user if provided
      if (res.body.trim().isNotEmpty) {
        try {
          final body = json.decode(res.body) as Map<String, dynamic>;
          final userJson = body['user'] ?? body; // be tolerant
          return User.fromJson(userJson as Map<String, dynamic>);
        } catch (e) {
          // fallthrough to fetchProfile
        }
      }

      // If server returned no user, fetch profile using GET /me
      try {
        return await fetchProfile();
      } catch (e) {
        throw ApiException('Profile updated but failed to fetch user', statusCode: res.statusCode, details: {'body': res.body});
      }
    }

    throw ApiException(_parseErrorMessage(res), statusCode: res.statusCode, details: {'body': res.body});
  }


  /// Change password: POST /me/change-password
  /// Backend example keys: currentPassword, newPassword
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/me/change-password');
    http.Response res;
    try {
      res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'currentPassword': currentPassword, 'newPassword': newPassword}),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }

    // Accept 200 or 204 as success depending on backend
    if (res.statusCode == 200 || res.statusCode == 204) {
      return;
    }

    // Important: backend invalidates refresh tokens on password change — handle accordingly in caller
    throw ApiException(_parseErrorMessage(res), statusCode: res.statusCode, details: {'body': res.body});
  }

  /// Delete account: DELETE /me
  Future<void> deleteAccount({String? password}) async {
    final uri = Uri.parse('$_baseUrl/me');
    http.Response res;
    try {
      if (password != null && password.isNotEmpty) {
        res = await _client.delete(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'password': password}),
        );
      } else {
        res = await _client.delete(
          uri,
          headers: {'Content-Type': 'application/json'},
        );
      }
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }

    // debug
    print('deleteAccount status=${res.statusCode} body=${res.body}');

    if (res.statusCode == 200 || res.statusCode == 204) {
      // Ensure local tokens cleared so user is signed out
      await _tokenStorage.clear();
      return;
    }

    throw ApiException(_parseErrorMessage(res), statusCode: res.statusCode, details: {'body': res.body});
  }


  /// Manual refresh: POST /auth/refresh (calls raw client to avoid recursion)
  Future<void> manualRefresh() async {
    final refresh = await _tokenStorage.readRefreshToken();
    if (refresh == null) throw ApiException('No refresh token stored');

    final uri = Uri.parse('$_baseUrl/auth/refresh');
    final raw = http.Client();
    http.Response res;
    try {
      res = await raw.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refresh}),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } finally {
      raw.close();
    }

    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final newAccess = body['accessToken'] as String?;
      final newRefresh = body['refreshToken'] as String?;
      if (newAccess != null && newRefresh != null) {
        await _tokenStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
        return;
      }
      throw ApiException('Invalid refresh response', statusCode: res.statusCode, details: {'body': res.body});
    }

    throw ApiException(_parseErrorMessage(res), statusCode: res.statusCode, details: {'body': res.body});
  }

}
