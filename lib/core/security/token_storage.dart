import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final FlutterSecureStorage _secureStorage;
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  TokenStorage({FlutterSecureStorage? storage})
      : _secureStorage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _secureStorage.write(key: _kAccess, value: accessToken);
    await _secureStorage.write(key: _kRefresh, value: refreshToken);
  }

  Future<String?> readAccessToken() => _secureStorage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _secureStorage.read(key: _kRefresh);

  Future<void> clear() async {
    await _secureStorage.delete(key: _kAccess);
    await _secureStorage.delete(key: _kRefresh);
  }
}
