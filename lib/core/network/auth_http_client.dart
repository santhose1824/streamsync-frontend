import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../security/token_storage.dart';
import '../../core/network/api_exception.dart';

class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;
  final TokenStorage _tokenStorage;
  final String baseUrl;

  Future<void>? _refreshing;

  AuthHttpClient({
    http.Client? inner,
    required TokenStorage tokenStorage,
    required this.baseUrl,
  })  : _inner = inner ?? http.Client(),
        _tokenStorage = tokenStorage;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Normalize relative path: if the caller passed a relative path, convert to absolute
    Uri url = request.url;
    if (!url.isAbsolute && url.path.startsWith('/')) {
      url = Uri.parse('$baseUrl${url.path}');
    }

    // Read access token and attach header if present
    final access = await _tokenStorage.readAccessToken();
    if (access != null && access.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $access';
    }

    // Debug print request
    print('DEBUG HTTP -> ${request.method} ${url.toString()} headers=${request.headers}');

    // If request has a body and is a Request (not StreamedRequest), preserve it
    http.BaseRequest toSend;
    if (request is http.Request) {
      final req = http.Request(request.method, url);
      req.headers.addAll(request.headers);
      req.bodyBytes = request.bodyBytes;
      toSend = req;
    } else {
      // For other BaseRequest types (rare), try to set url and headers only.
      request = _cloneWithUrlAndHeaders(request, url, request.headers);
      toSend = request;
    }

    http.StreamedResponse response = await _inner.send(toSend);

    print('DEBUG HTTP <- ${request.method} ${url.toString()} status=${response.statusCode}');

    // If unauthorized, drain body, attempt refresh once, retry
    if (response.statusCode == 401) {
      final bodyBytes = await response.stream.toBytes();
      final bodyStr = bodyBytes.isNotEmpty ? utf8.decode(bodyBytes) : '';
      print('DEBUG 401 body=$bodyStr');

      try {
        await _attemptRefresh();
      } catch (e, st) {
        print('DEBUG refresh failed: $e');
        // Return original 401 response (we already drained it)
        // Build a new StreamedResponse with same status to propagate
        return http.StreamedResponse(Stream.value(bodyBytes), 401, request: toSend, reasonPhrase: response.reasonPhrase);
      }

      // After refresh, attach new token and retry once
      final newAccess = await _tokenStorage.readAccessToken();
      if (newAccess != null && newAccess.isNotEmpty) {
        final retryReq = _cloneRequestWithNewUrlAndHeaders(toSend, url, {
          ...toSend.headers,
          'Authorization': 'Bearer $newAccess',
        });
        print('DEBUG retrying ${retryReq.method} $url with refreshed token');
        response = await _inner.send(retryReq);
        print('DEBUG retry status=${response.statusCode}');
      }
    }

    return response;
  }

  Future<void> _attemptRefresh() {
    if (_refreshing != null) return _refreshing!;
    final completer = Completer<void>();
    _refreshing = completer.future;

    _doRefresh().then((_) {
      completer.complete();
    }).catchError((e, st) {
      completer.completeError(e, st);
    }).whenComplete(() {
      _refreshing = null;
    });

    return completer.future;
  }

  Future<void> _doRefresh() async {
    final refresh = await _tokenStorage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw ApiException('No refresh token stored');
    }

    final uri = Uri.parse('$baseUrl/auth/refresh');
    final raw = http.Client();
    try {
      print('DEBUG calling refresh endpoint $uri');
      final res = await raw.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refresh}),
      );
      print('DEBUG refresh status=${res.statusCode} body=${res.body}');
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final newAccess = body['accessToken'] as String?;
        final newRefresh = body['refreshToken'] as String?;
        if (newAccess != null && newRefresh != null) {
          await _tokenStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
          print('DEBUG refresh saved new tokens');
          return;
        }
        throw ApiException('Invalid refresh response', statusCode: res.statusCode, details: {'body': res.body});
      }
      throw ApiException('Refresh failed', statusCode: res.statusCode, details: {'body': res.body});
    } finally {
      raw.close();
    }
  }

  // Helpers to clone requests (simple conservative approach)
  http.BaseRequest _cloneRequestWithNewUrlAndHeaders(http.BaseRequest req, Uri newUrl, Map<String, String> headers) {
    final r = http.Request(req.method, newUrl);
    r.headers.addAll(headers);
    if (req is http.Request) r.bodyBytes = req.bodyBytes;
    return r;
  }

  http.BaseRequest _cloneWithUrlAndHeaders(http.BaseRequest req, Uri newUrl, Map<String, String> headers) {
    final r = http.Request(req.method, newUrl);
    r.headers.addAll(headers);
    if (req is http.Request) r.bodyBytes = req.bodyBytes;
    return r;
  }

  @override
  void close() => _inner.close();
}



// Internal helper wrapper to hold captured body bytes and delegate finalize synchronously
class _PreparedRequest extends http.BaseRequest {
  final http.Request _innerRequest;
  final List<int>? bodyBytes;

  _PreparedRequest(http.Request request, {this.bodyBytes})
      : _innerRequest = request,
        super(request.method, request.url) {
    headers.addAll(request.headers);
  }

  @override
  Uri get url => _innerRequest.url;

  @override
  String get method => _innerRequest.method;

  // finalize must be synchronous and return a ByteStream
  @override
  http.ByteStream finalize() {
    if (bodyBytes != null) {
      return http.ByteStream.fromBytes(bodyBytes!);
    }
    return _innerRequest.finalize();
  }
}
