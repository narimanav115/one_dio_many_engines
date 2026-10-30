import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:one_dio_many_engines/one_dio_many_engines.dart';

Future<void> main() async {
  final proxy = ValueNotifier<String?>(null);

  final client = NetworkClient(
    baseUrl: 'https://httpbin.org',
    isGmsAvailable: true,
    proxy: proxy,
    interceptors: [LogInterceptor(responseBody: false)],
  );

  final response = await client.dio.get<Map<String, Object?>>('/get');
  debugPrint('${client.engine.value}: ${response.statusCode}');

  proxy.value = '192.168.0.10:8888';
  debugPrint('Switched to ${client.engine.value} without recreating Dio');

  const protocol = MessagePackBrotliProtocol();
  debugPrint('Handshake: ${MessagePackBrotliProtocol.handshakeRequest}');

  final frame = protocol.writeMessage(
    const InvocationMessage(target: 'Subscribe', arguments: ['football']),
  );
  for (final message in protocol.parseMessages(frame)) {
    debugPrint('Parsed $message');
  }

  client.dispose();
  proxy.dispose();
}
