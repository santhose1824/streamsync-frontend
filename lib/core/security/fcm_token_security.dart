import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FcmTokenStorage {
  final FlutterSecureStorage _storage;
  static const _kFcm = 'fcm_token';

  FcmTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save(String token) => _storage.write(key: _kFcm, value: token);
  Future<String?> read() => _storage.read(key: _kFcm);
  Future<void> clear() => _storage.delete(key: _kFcm);
}
