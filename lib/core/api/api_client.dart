import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Thrown for any non-2xx response or network failure, with a human message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});
  final String message;
  final int? statusCode;
  final dynamic data;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Dio wrapper: attaches the bearer token, sets the `X-Scan-App` header the
/// backend uses to detect the mobile client, and normalises errors.
class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            'X-Scan-App': '1',
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  /// Multipart POST for file uploads. [files] maps a field name to a local file
  /// path (e.g. {'invoice_file': '/path/to.pdf'}).
  Future<dynamic> postMultipart(
    String path, {
    Map<String, dynamic> fields = const {},
    Map<String, String> files = const {},
  }) async {
    final map = <String, dynamic>{...fields};
    for (final e in files.entries) {
      map[e.key] = await MultipartFile.fromFile(e.value, filename: e.value.split('/').last);
    }
    return _send(() => _dio.post(path, data: FormData.fromMap(map)));
  }

  Future<dynamic> _send(Future<Response> Function() request) async {
    try {
      final res = await request();
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// The mobile API wraps most payloads in `{success: true, data: {...}}`
  /// (list / scan-state / box-loading / racking / short-forms). Unwrap to the
  /// inner payload. Flat responses (login, dashboard/counts, the scan result
  /// which carries `scan_state` at top level) have no `data` key and pass through.
  dynamic _unwrap(dynamic body) {
    if (body is Map && body['success'] == true && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  ApiException _map(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Something went wrong. Please try again.';

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      message = 'Network error — check your connection.';
    } else if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else if (status == 401) {
      message = 'Session expired. Please log in again.';
    } else if (status == 403) {
      message = 'You do not have access to this.';
    }
    return ApiException(message, statusCode: status, data: data);
  }
}
