import 'dart:io';

import '../../hook/build_download_client.dart';

Future<void> main() async {
  final client = buildDownloadClient();
  if (client.options.connectTimeout != const Duration(seconds: 20) ||
      client.options.receiveTimeout != const Duration(minutes: 3)) {
    throw StateError('Build download deadlines changed');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serving = server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write('{"fixture":true}');
    await request.response.close();
  });
  try {
    final response = await client.get<Map<String, dynamic>>(
      'http://127.0.0.1:${server.port}/fixture',
    );
    if (response.statusCode != 200 || response.data?['fixture'] != true) {
      throw StateError('Build download fixture failed');
    }
    stdout.writeln(
      'PASS: build download deadlines and local HTTP fixture (no remote binary)',
    );
  } finally {
    client.close(force: true);
    await serving.cancel();
    await server.close(force: true);
  }
}
