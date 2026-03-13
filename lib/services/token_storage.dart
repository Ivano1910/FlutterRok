import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  static const _firstNameKey = 'first_name';
  static const _lastNameKey = 'last_name';
  static const _phoneKey = 'phone';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ---- profile ----
  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    await _storage.write(key: _firstNameKey, value: firstName);
    await _storage.write(key: _lastNameKey, value: lastName);
    await _storage.write(key: _phoneKey, value: phone);
  }

  Future<Map<String, String?>> getProfile() async {
    final first = await _storage.read(key: _firstNameKey);
    final last = await _storage.read(key: _lastNameKey);
    final phone = await _storage.read(key: _phoneKey);
    return {"first_name": first, "last_name": last, "phone": phone};
  }

  Future<void> deleteProfile() async {
    await _storage.delete(key: _firstNameKey);
    await _storage.delete(key: _lastNameKey);
    await _storage.delete(key: _phoneKey);
  }
}