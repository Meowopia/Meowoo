import 'package:dio/dio.dart';

class MiruRequest {
  static final _dio = Dio();
  static late final Uri baseHost;
  static late final Uri proxyBaseUrl;

  static void ensureInitalized({required String host}) {
    baseHost = Uri.parse(host);
    proxyBaseUrl = baseHost.replace(path: '/proxy/');
  }

  static Future<dynamic> get(String url, {Options? options}) async {
    final response = await _dio.get(proxyUrl(url).toString(), options: options);
    return response.data;
  }

  /// Typed streaming response for consumers that need status and headers.
  /// Existing get() intentionally continues returning only decoded body data.
  static Future<Response<ResponseBody>> getStreamResponse(
    String url, {
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) => _dio.get<ResponseBody>(
    proxyUrl(url).toString(),
    options: Options(headers: headers, responseType: ResponseType.stream),
    cancelToken: cancelToken,
  );

  static Future<dynamic> post(
    String url,
    Map<String, dynamic> data, {
    Options? options,
  }) async {
    final response = await _dio.post(
      proxyUrl(url).toString(),
      data: data,
      options: options,
    );
    return response.data;
  }

  static Future<dynamic> rawGet(String url, {Options? options}) async {
    final response = await _dio.get(url, options: options);
    return response.data;
  }

  static Future<dynamic> rawPost(
    String url,
    Map<String, dynamic> data, {
    Options? options,
  }) async {
    final response = await _dio.post(url, data: data, options: options);
    return response.data;
  }

  static Uri proxyUrl(String url) {
    return proxyBaseUrl.resolve(Uri.encodeComponent(url));
  }

  static Future<void> download(String url, String savePath) async {
    await _dio.download(proxyUrl(url).toString(), savePath);
  }

  /// Downloads [url] directly without going through the proxy.
  /// Use this for user-supplied URLs (e.g. extension imports) that
  /// should be fetched as-is.
  static Future<void> rawDownload(String url, String savePath) async {
    await _dio.download(url, savePath);
  }
}
