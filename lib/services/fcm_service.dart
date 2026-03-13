import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notifications_service.dart';

class FcmService {
  FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<String?> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('FCM permission status: ${settings.authorizationStatus}');
    }

    final token = await _messaging.getToken();

    if (kDebugMode) {
      print('FCM TOKEN: $token');
    }

    _messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('FCM TOKEN REFRESHED: $newToken');
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('Foreground message received!');
        print('Title: ${message.notification?.title}');
        print('Body: ${message.notification?.body}');
        print('Data: ${message.data}');
      }
      final title = message.notification?.title;
      final body = message.notification?.body;

      if (title != null && body != null) {          
        await NotificationsService.showRemoteNotification(
        title: title,
        body: body,
        );
      }
    });

    return token;
  }
}