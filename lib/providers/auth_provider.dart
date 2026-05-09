import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import '../services/fcm_service.dart';
import '../services/api_service.dart';

// State: null = loading, false = unauthenticated, true = authenticated
class AuthNotifier extends StateNotifier<bool?> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(null) {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    try {
      final token = await _ref.read(tokenStorageProvider).getToken();
      state = token != null;
    } catch (e) {
      state = false;
    }
  }

  Future<void> login(String token) async {
    await _ref.read(tokenStorageProvider).saveToken(token);
    state = true;

    try {
      if (!kIsWeb) {
        final fcmToken = await FcmService.init();

        if (fcmToken != null) {
          final api = _ref.read(apiServiceProvider);

          final platform = defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';

          await api.registerDeviceToken(
            token: fcmToken,
            platform: platform,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to register FCM token: $e");
      }
    }
  }

  Future<void> logout() async {
    await _ref.read(tokenStorageProvider).deleteToken();
    await _ref.read(tokenStorageProvider).deleteProfile();
    state = false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, bool?>((ref) {
  return AuthNotifier(ref);
});