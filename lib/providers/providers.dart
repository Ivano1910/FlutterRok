import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiService(tokenStorage, ref);
});
