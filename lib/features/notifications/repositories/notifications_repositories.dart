import 'dart:convert';
import 'dart:io';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/notifications/models/app_notifications.dart';
import 'package:http/http.dart' as http;


class NotificationsRepository {
  final http.Client _client;
  final String _baseUrl;

  NotificationsRepository({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  Future<List<AppNotification>> list({int limit = 20, DateTime? since}) async {
    final sinceParam = since != null ? '&since=${Uri.encodeComponent(since.toUtc().toIso8601String())}' : '';
    final uri = Uri.parse('$_baseUrl/notifications?limit=$limit$sinceParam');

    http.Response res;
    try {
      res = await _client.get(uri);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error');
    }

    if (res.statusCode == 200) {
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      final rawList = decoded['notifications'] as List<dynamic>? ?? [];
      return rawList.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw ApiException('Failed to list notifications', statusCode: res.statusCode, details: {'body': res.body});
  }

  Future<AppNotification> get(String id) async {
    final uri = Uri.parse('$_baseUrl/notifications/$id');
    http.Response res;
    try {
      res = await _client.get(uri);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error');
    }

    if (res.statusCode == 200) {
      return AppNotification.fromJson(json.decode(res.body) as Map<String, dynamic>);
    }
    throw ApiException('Failed to fetch notification', statusCode: res.statusCode, details: {'body': res.body});
  }

  Future<int> markRead(List<String> ids) async {
    final uri = Uri.parse('$_baseUrl/notifications/mark-read');
    http.Response res;
    try {
      res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': ids}),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error');
    }

    if (res.statusCode == 200) {
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      return decoded['updated'] as int? ?? 0;
    }
    throw ApiException('Failed to mark read', statusCode: res.statusCode, details: {'body': res.body});
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('$_baseUrl/notifications/$id');
    http.Response res;
    try {
      res = await _client.delete(uri);
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error');
    }

    if (res.statusCode == 204) return;
    throw ApiException('Failed to delete notification', statusCode: res.statusCode, details: {'body': res.body});
  }

  Future<Map<String, dynamic>> sendTest({
    required String title,
    required String body,
    String? idempotencyKey,
  }) async {
    final uri = Uri.parse('$_baseUrl/notifications/send-test');
    http.Response res;
    try {
      res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'body': body,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        }),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      throw ApiException('Network error');
    }

    // FIXED: Accept 202 (Accepted) status code for async operations
    if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 202) {
      try {
        return json.decode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'raw': res.body};
      }
    }
    throw ApiException('Failed to send test notification', statusCode: res.statusCode, details: {'body': res.body});
  }
}