import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'token_storage.dart';
import '../providers/auth_provider.dart';
import '../services/notifications_service.dart';


class ApiService {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Ref _ref;

  ApiService(this._tokenStorage, this._ref)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://192.168.18.229:8000',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // ✅ NEVER attach token to auth endpoints
          final path = options.path;

          if (path != '/login' && path != '/register') {
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

          // ✅ ignore 401 from login/register (wrong creds etc)
          if (e.response?.statusCode == 401 && path != '/login' && path != '/register') {
            await _ref.read(authProvider.notifier).logout();
        }

        return handler.next(e);
      },
      ),
    );
  }

  // Keep this so older code using .client won't crash
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

  // ---------- AVAILABILITY ----------
  Future<List<String>> getAvailability(String day) async {
    try {
      final res = await _dio.get('/availability', queryParameters: {'day': day});
      final slots = (res.data['slots'] as List?) ?? [];
      return slots.map((e) => e.toString()).toList();
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

  Future<List<Map<String, dynamic>>> adminListWorkingDays({
    required String start, // YYYY-MM-DD
    required String end,   // YYYY-MM-DD
  }) async {
    try {
      final res = await _dio.get(
        '/admin/working-days',
        queryParameters: {'start': start, 'end': end},
      );
      final list = (res.data['days'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    }
  }

  Future<Map<String, dynamic>> adminUpsertWorkingDay({
    required String day, // YYYY-MM-DD
    required bool isClosed,
    String? openTime,  // "HH:MM" or null
    String? closeTime, // "HH:MM" or null
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

  Future<List<Map<String, dynamic>>> adminGetBookings(String day) async {
    try {
      final res = await _dio.get(
        '/admin/bookings',
        queryParameters: {'day': day},
      );

      final list = (res.data['bookings'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw _prettyError(e);
    } 
  }

  // ---------- ERRORS ----------
  String _prettyError(DioException e) {
    final status = e.response?.statusCode;

    if (status == 409) return "Odabrani termin je zauzet.";
    if (status == 429) return "Previše zahtjeva. Pokušajte kasnije.";
    // Let backend detail show for 400
    if (status == 401) return "Neispravni podaci ili istekla sesija.";

    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return "Greška u komunikaciji s poslužiteljem.";
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
    required int days, // 3 / 7 / 14
    String? windowStart, // "HH:mm"
    String? windowEnd,   // "HH:mm"
  }) async {
    try {
      final data = <String, dynamic>{
        'days': days,
        'window_start': ?windowStart,
        'window_end': ?windowEnd,
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

  Future<void> adminSetPeriods(String day, List<Map<String, String>> periods) async {
    try {
      await _dio.put(
        '/admin/working-days/$day/periods',
        data: {'periods': periods},
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
  // ---------- ADMIN: WEEKLY SCHEDULE ----------

// Returns: [{"weekday":0,"start_time":"08:00:00","end_time":"13:00:00"}, ...]
Future<List<Map<String, dynamic>>> adminGetWeeklyPeriods() async {
  try {
    final res = await _dio.get('/admin/weekly-periods');
    final list = (res.data['periods'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  } on DioException catch (e) {
    throw _prettyError(e);
  }
}

// periods: [{"start_time":"08:00:00","end_time":"13:00:00"}, ...]
Future<List<Map<String, dynamic>>> adminPutWeeklyPeriods({
  required int weekday, // 0..6
  required List<Map<String, String>> periods,
}) async {
  try {
    final res = await _dio.put(
      '/admin/weekly-periods/$weekday',
      data: {'periods': periods},
    );
    final list = (res.data['periods'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  } on DioException catch (e) {
    throw _prettyError(e);
  }
}

// ---------- ADMIN: OVERRIDES ----------

// Returns: {override: {...} or null, periods: [...]}
Future<Map<String, dynamic>> adminGetOverride(String day) async {
  try {
    final res = await _dio.get('/admin/overrides/$day');
    return Map<String, dynamic>.from(res.data);
  } on DioException catch (e) {
    throw _prettyError(e);
  }
}

Future<Map<String, dynamic>> adminPutOverride({
  required String day, // YYYY-MM-DD
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
}