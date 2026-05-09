import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'token_storage.dart';
import '../providers/auth_provider.dart';
import '../services/notifications_service.dart';

class ApiService {
  static const String businessSlug = 'barber-rok';

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Ref _ref;

  ApiService(this._tokenStorage, this._ref)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://booking-production-84a4.up.railway.app',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'X-Business-Slug': 'barber-rok',
            },
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['X-Business-Slug'] = businessSlug;

          final path = options.path;

          if (path != '/login' &&
              path != '/register' &&
              path != '/forgot-password' &&
              path != '/reset-password' &&
              path != '/verify-email') {
            final token = await _tokenStorage.getToken();

            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } else {
            options.headers.remove('Authorization');
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final path = e.requestOptions.path;

          if (e.response?.statusCode == 401 &&
              path != '/login' &&
              path != '/register') {
            await _ref.read(authProvider.notifier).logout();
          }

          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;

  // ---------- AUTH ----------
  Future<String> login(String email, String password) async {
    try {
      final res = await _dio.post(
        '/login',
        data: {
          'username': email,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = res.data['access_token'];

      if (token == null || token is! String) {
        throw Exception('Token missing in response');
      }

      return token;
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String registrationCode,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      await _dio.post(
        '/register',
        data: {
          'email': email,
          'password': password,
          'registration_code': registrationCode,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(
        '/forgot-password',
        data: {
          'email': email,
        },
      );
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/reset-password',
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> verifyEmail(String token) async {
    try {
      await _dio.get(
        '/verify-email',
        queryParameters: {
          'token': token,
        },
      );
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- USER ----------
  Future<Map<String, dynamic>> getMe() async {
    try {
      final res = await _dio.get('/me');
      return Map<String, dynamic>.from(res.data['user']);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- AVAILABILITY ----------
  Future<List<String>> getAvailability(String day) async {
    try {
      final res = await _dio.get(
        '/availability',
        queryParameters: {'day': day},
      );

      final slots = (res.data['slots'] as List?) ?? [];

      return slots.map((e) {
        if (e is Map && e['start_time'] != null) {
          return e['start_time'].toString();
        }

        return e.toString();
      }).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- BOOKINGS ----------
  Future<Map<String, dynamic>> createBooking({
    required String customerName,
    required DateTime startTime,
  }) async {
    try {
      final res = await _dio.post(
        '/bookings',
        data: {
          'customer_name': customerName,
          'start_time': startTime.toLocal().toIso8601String(),
        },
      );

      if (res.data is Map && res.data['ok'] == true) {
        final booking = Map<String, dynamic>.from(res.data['booking']);

        await NotificationsService.scheduleBookingReminders(
          bookingId: booking['id'] as int,
          bookingStartLocal: DateTime.parse(booking['start_time']).toLocal(),
          titleName: (booking['customer_name'] ?? customerName).toString(),
        );

        return booking;
      }

      throw Exception('Failed to create booking');
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    try {
      final res = await _dio.get('/me/bookings');
      final list = (res.data['bookings'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> cancelBooking(int id) async {
    try {
      final res = await _dio.delete('/bookings/$id');

      if (res.statusCode != 204) {
        throw Exception('Cancel failed');
      }

      await NotificationsService.cancelBookingReminders(id);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- ADMIN BOOKINGS ----------
  Future<List<Map<String, dynamic>>> adminGetBookings(String day) async {
    try {
      final res = await _dio.get(
        '/admin/bookings',
        queryParameters: {
          'day': day,
        },
      );

      final list = (res.data['bookings'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- ADMIN WORKING DAYS ----------
  Future<List<Map<String, dynamic>>> adminListWorkingDays({
    required String start,
    required String end,
  }) async {
    try {
      final res = await _dio.get(
        '/admin/working-days',
        queryParameters: {
          'start': start,
          'end': end,
        },
      );

      final list = (res.data['days'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<Map<String, dynamic>> adminUpsertWorkingDay({
    required String day,
    required bool isClosed,
    String? openTime,
    String? closeTime,
  }) async {
    try {
      final res = await _dio.put(
        '/admin/working-days/$day',
        data: {
          'open_time': openTime,
          'close_time': closeTime,
          'is_closed': isClosed,
        },
      );

      return Map<String, dynamic>.from(res.data['working_day']);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> adminDeleteWorkingDay(String day) async {
    try {
      await _dio.delete('/admin/working-days/$day');
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- ADMIN PERIODS ----------
  Future<List<Map<String, dynamic>>> adminGetPeriods(String day) async {
    try {
      final res = await _dio.get('/admin/working-days/$day/periods');
      final list = (res.data['periods'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> adminSetPeriods(
    String day,
    List<Map<String, String>> periods,
  ) async {
    try {
      await _dio.put(
        '/admin/working-days/$day/periods',
        data: {
          'periods': periods,
        },
      );
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> adminClearPeriods(String day) async {
    try {
      await _dio.delete('/admin/working-days/$day/periods');
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- ADMIN WEEKLY SCHEDULE ----------
  Future<List<Map<String, dynamic>>> adminGetWeeklyPeriods() async {
    try {
      final res = await _dio.get('/admin/weekly-periods');
      final list = (res.data['periods'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<List<Map<String, dynamic>>> adminPutWeeklyPeriods({
    required int weekday,
    required List<Map<String, String>> periods,
  }) async {
    try {
      final res = await _dio.put(
        '/admin/weekly-periods/$weekday',
        data: {
          'periods': periods,
        },
      );

      final list = (res.data['periods'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- ADMIN OVERRIDES ----------
  Future<Map<String, dynamic>> adminGetOverride(String day) async {
    try {
      final res = await _dio.get('/admin/overrides/$day');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<Map<String, dynamic>> adminPutOverride({
    required String day,
    required bool isClosed,
    String? note,
    required List<Map<String, String>> periods,
  }) async {
    try {
      final res = await _dio.put(
        '/admin/overrides/$day',
        data: {
          'is_closed': isClosed,
          'note': note,
          'periods': periods,
        },
      );

      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> adminDeleteOverride(String day) async {
    try {
      await _dio.delete('/admin/overrides/$day');
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- WAITLIST ----------
  Future<Map<String, dynamic>> getMyWaitlist() async {
    try {
      final res = await _dio.get('/me/waitlist');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<Map<String, dynamic>> joinWaitlist({
    required int days,
    String? windowStart,
    String? windowEnd,
  }) async {
    try {
      final data = <String, dynamic>{
        'days': days,
        'window_start': windowStart,
        'window_end': windowEnd,
      };

      final res = await _dio.post('/waitlist', data: data);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<void> leaveWaitlist(int id) async {
    try {
      await _dio.delete('/waitlist/$id');
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- DEVICES ----------
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _dio.post(
        '/devices/register',
        data: {
          'token': token,
          'platform': platform,
        },
      );
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  // ---------- ERRORS ----------
  String _prettyError(DioException e) {
    final status = e.response?.statusCode;

    if (status == 409) return 'Odabrani termin je zauzet.';
    if (status == 429) return 'Previše zahtjeva. Pokušajte kasnije.';
    if (status == 401) return 'Neispravni podaci ili istekla sesija.';

    final data = e.response?.data;

    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    return 'Greška u komunikaciji s poslužiteljem.';
  }
}