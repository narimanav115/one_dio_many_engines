import 'package:dio/dio.dart';

import 'adapter_factory_io.dart'
    if (dart.library.js_interop) 'adapter_factory_web.dart'
    as impl;
import 'apple_session_options.dart';
import 'network_engine.dart';

/// Creates the [HttpClientAdapter] for [engine].
///
/// [proxy] is `host:port` and is only used by [NetworkEngine.http2].
/// [apple] is only used by [NetworkEngine.cupertino].
HttpClientAdapter createHttpClientAdapter(
  NetworkEngine engine, {
  String? proxy,
  AppleSessionOptions apple = const AppleSessionOptions(),
}) => impl.createHttpClientAdapter(engine, proxy: proxy, apple: apple);
