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
      // If mounted check is not available in StateNotifier, we just set state.
      // StateNotifier disposes automatically when provider is disposed, but here it's likely alive for app life.
      state = token != null;
    } catch (e) {
      // In case of storage error, default to unauthenticated
      state = false;
    }
  }

  Future<void> login(String token) async {
    await _ref.read(tokenStorageProvider).saveToken(token);
    state = true;

    try {
      final fcmToken = await FcmService.init();

      if (fcmToken != null) {
        final api = _ref.read(apiServiceProvider);

        await api.registerDeviceToken(
          token: fcmToken,
          platform: 'android',
        );
      }
    } catch (e) {
      print("Failed to register FCM token: $e");
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
