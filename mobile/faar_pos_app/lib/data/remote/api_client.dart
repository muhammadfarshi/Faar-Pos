import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_constants.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  AppException({required this.message, this.statusCode, this.isNetworkError = false});

  @override
  String toString() => message;
}

class AuthInterceptor extends QueuedInterceptorsWrapper {
  final Ref ref;
  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add token logic
    options.headers['Authorization'] = 'Bearer mocked_token';
    handler.next(options);
  }
}

class RefreshInterceptor extends QueuedInterceptorsWrapper {
  final Ref ref;
  RefreshInterceptor(this.ref);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Handle refresh logic
    }
    handler.next(err);
  }
}

class IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' &&
        options.path.contains('/transactions') &&
        !options.path.contains('sync-batch')) {
      if (!options.headers.containsKey('Idempotency-Key')) {
        options.headers['Idempotency-Key'] = const Uuid().v4();
      }
    }
    handler.next(options);
  }
}

class ApiClient {
  final Dio _dio;

  ApiClient({required Dio dio}) : _dio = dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? headers}) async {
    return await _dio.post(path, data: data, options: Options(headers: headers));
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    RefreshInterceptor(ref),
    IdempotencyInterceptor(),
    PrettyDioLogger(requestHeader: false, responseBody: false),
  ]);

  return ApiClient(dio: dio);
});
