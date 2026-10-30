import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_compatibility_layer/dio_compatibility_layer.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

import 'apple_session_options.dart';
import 'network_engine.dart';

const _idleTimeout = Duration(seconds: 3);
const _handshakeTimeout = Duration(seconds: 10);

HttpClientAdapter createHttpClientAdapter(
  NetworkEngine engine, {
  String? proxy,
  AppleSessionOptions apple = const AppleSessionOptions(),
}) => switch (engine) {
  NetworkEngine.cronet => ConversionLayerAdapter(_cronetClient()),
  NetworkEngine.cupertino => ConversionLayerAdapter(_cupertinoClient(apple)),
  NetworkEngine.http2 || NetworkEngine.browser => _http2Adapter(proxy),
};

CronetClient _cronetClient() => CronetClient.fromCronetEngine(
  CronetEngine.build(
    enableBrotli: true,
    enableHttp2: true,
    enableQuic: true,
  ),
);

CupertinoClient _cupertinoClient(AppleSessionOptions options) {
  final config = URLSessionConfiguration.defaultSessionConfiguration()
    ..waitsForConnectivity = options.waitsForConnectivity
    ..allowsConstrainedNetworkAccess = options.allowsConstrainedNetworkAccess
    ..allowsExpensiveNetworkAccess = options.allowsExpensiveNetworkAccess
    ..httpMaximumConnectionsPerHost = options.maxConnectionsPerHost
    ..timeoutIntervalForRequest = options.requestTimeout;

  return CupertinoClient.fromSessionConfiguration(config);
}

/// Offering both `h2` and `http/1.1` in ALPN lets servers that only speak
/// HTTP/1.1 finish the TLS handshake, so `fallbackAdapter` actually kicks in.
Http2Adapter _http2Adapter(String? proxy) {
  final hasProxy = proxy != null && proxy.isNotEmpty;

  return Http2Adapter(
    ConnectionManager(
      idleTimeout: _idleTimeout,
      handshakeTimeout: _handshakeTimeout,
      supportedProtocols: const ['h2', 'http/1.1'],
      onClientCreate: hasProxy
          ? (_, config) => config
              ..proxy = Uri.parse('http://$proxy')
              ..onBadCertificate = (_) => true
          : null,
    ),
    fallbackAdapter: IOHttpClientAdapter(),
  );
}
