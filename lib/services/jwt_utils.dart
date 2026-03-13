import 'dart:convert';

String? jwtRole(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  final payload = parts[1];
  final normalized = base64Url.normalize(payload);
  final decoded = utf8.decode(base64Url.decode(normalized));

  final map = json.decode(decoded);
  if (map is Map && map['role'] is String) {
    return map['role'] as String;
  }
  return null;
}