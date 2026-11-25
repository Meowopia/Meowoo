import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Build downloads honour explicit process proxy settings without changing
/// machine settings or disabling TLS verification. Bound stalled connections.
Dio buildDownloadClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 3),
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()
          ..findProxy = (uri) => HttpClient.findProxyFromEnvironment(uri),
  );
  return dio;
}
