import 'package:flutter/foundation.dart';

/// The HTTP stack that sits under Dio.
enum NetworkEngine {
  /// Chromium networking on Android: HTTP/3 (QUIC), HTTP/2, Brotli.
  cronet,

  /// URLSession on iOS and macOS.
  cupertino,

  /// Pure Dart HTTP/2 with an HTTP/1.1 fallback.
  http2,

  /// The browser's own stack on web.
  browser,
}

/// Picks the engine for the current platform and environment.
///
/// A non-empty [proxy] always selects [NetworkEngine.http2], because only a
/// Dart-level client can route through a debugging proxy such as Charles.
NetworkEngine selectEngine({
  required TargetPlatform platform,
  required bool isWeb,
  required bool isGmsAvailable,
  String? proxy,
}) {
  if (isWeb) return NetworkEngine.browser;
  if (proxy != null && proxy.isNotEmpty) return NetworkEngine.http2;

  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => NetworkEngine.cupertino,
    TargetPlatform.android when isGmsAvailable => NetworkEngine.cronet,
    _ => NetworkEngine.http2,
  };
}
