import 'dart:convert';
import 'package:frontend/core/security/fcm_token_security.dart';
import 'package:http/http.dart' as http;
import 'auth_http_client.dart'; // your AuthHttpClient file


class FcmService {
  final AuthHttpClient _client;
  final FcmTokenStorage _storage;
  final String baseUrl; // same base as AuthHttpClient.baseUrl (optional duplicate)

  FcmService({
    required AuthHttpClient client,
    required FcmTokenStorage storage,
    required this.baseUrl,
  })  : _client = client,
        _storage = storage;

  /// Register the fcm token for a user on the backend.
  /// Returns the server response body (if any) or throws on non-2xx.
  Future<void> registerToken({
    required String userId,
    required String token,
    String? platform, // "android" | "ios" etc
  }) async {
    final uri = Uri.parse('/users/$userId/fcm-token'); // AuthHttpClient will normalize
    final req = http.Request('POST', uri);
    req.headers['Content-Type'] = 'application/json';
    req.body = json.encode({
      'token': token,
      if (platform != null) 'platform': platform,
    });
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to register FCM token (${res.statusCode}): ${res.body}');
    }
    // Save locally so we can delete later
    await _storage.save(token);
  }

  /// Delete by token (use when you only have the token).
  Future<void> deleteTokenByToken({
    required String userId,
    required String token,
  }) async {
    final uri = Uri.parse('/users/$userId/fcm-token');
    final req = http.Request('DELETE', uri);
    req.headers['Content-Type'] = 'application/json';
    req.body = json.encode({'token': token});
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      throw Exception('Failed to delete FCM token (${res.statusCode}): ${res.body}');
    }
    await _storage.clear();
  }

  /// Delete by id (if server returns an id when registering and you store it).
  Future<void> deleteTokenById({
    required String userId,
    required String id,
  }) async {
    final uri = Uri.parse('/users/$userId/fcm-token/$id');
    final req = http.Request('DELETE', uri);
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      throw Exception('Failed to delete FCM token by id (${res.statusCode}): ${res.body}');
    }
    await _storage.clear();
  }

  /// Convenience: delete token previously saved in local storage (if any).
  Future<void> deleteSavedTokenForUser({required String userId}) async {
    final token = await _storage.read();
    if (token == null) return;
    await deleteTokenByToken(userId: userId, token: token);
  }
}
