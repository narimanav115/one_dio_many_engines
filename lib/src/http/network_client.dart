import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'adapter_factory.dart';
import 'apple_session_options.dart';
import 'network_engine.dart';
import 'response_decoder.dart';

/// Owns a single [Dio] and keeps its engine in sync with the environment.
///
/// When [proxy] changes, a new adapter is created and assigned to the same
/// [Dio] instance. Interceptors, options and transformer stay untouched.
class NetworkClient {
  NetworkClient({
    required String baseUrl,
    required this._isGmsAvailable,
    this._proxy,
    List<Interceptor> interceptors = const [],
    Duration timeout = const Duration(seconds: 20),
    this._apple = const AppleSessionOptions(),
    @visibleForTesting TargetPlatform? platform,
    @visibleForTesting bool? isWeb,
  }) : _timeout = timeout,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb,
       dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: timeout,
           sendTimeout: timeout,
           receiveTimeout: timeout,
           contentType: Headers.jsonContentType,
         ),
       ) {
    dio.interceptors.addAll(interceptors);
    _applyEngine();
    _proxy?.addListener(_applyEngine);
  }

  final Dio dio;

  final bool _isGmsAvailable;
  final ValueListenable<String?>? _proxy;
  final Duration _timeout;
  final AppleSessionOptions _apple;
  final TargetPlatform _platform;
  final bool _isWeb;

  final _engine = ValueNotifier<NetworkEngine>(NetworkEngine.http2);

  /// The engine currently in use. Handy for a debug screen.
  ValueListenable<NetworkEngine> get engine => _engine;

  void dispose() {
    _proxy?.removeListener(_applyEngine);
    _engine.dispose();
    _close(dio.httpClientAdapter, force: true);
  }

  void _applyEngine() {
    final proxy = _proxy?.value;
    final engine = selectEngine(
      platform: _platform,
      isWeb: _isWeb,
      isGmsAvailable: _isGmsAvailable,
      proxy: proxy,
    );

    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = createHttpClientAdapter(
      engine,
      proxy: proxy,
      apple: _apple,
    );
    configureResponseDecoder(dio);
    _engine.value = engine;

    // Requests already sent through the old adapter get time to finish.
    // CupertinoClient throws if it is closed with requests in flight.
    Timer(_timeout, () => _close(previous));
  }

  void _close(HttpClientAdapter adapter, {bool force = false}) {
    try {
      adapter.close(force: force);
    } on Object catch (error) {
      debugPrint('Failed to close $adapter: $error');
    }
  }
}
