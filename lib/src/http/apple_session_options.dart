/// URLSession settings for iOS and macOS.
class AppleSessionOptions {
  const AppleSessionOptions({
    this.waitsForConnectivity = false,
    this.allowsConstrainedNetworkAccess = true,
    this.allowsExpensiveNetworkAccess = true,
    this.maxConnectionsPerHost = 6,
    this.requestTimeout = const Duration(seconds: 20),
  });

  /// Wait for a network instead of failing at once when there is none,
  /// for example in a lift or a Wi-Fi dead zone.
  ///
  /// Requests then stay pending until a connection appears, so only enable
  /// it for requests that are fine to deliver late.
  final bool waitsForConnectivity;

  /// Allow requests while the user has Low Data Mode on.
  final bool allowsConstrainedNetworkAccess;

  /// Allow requests over cellular and personal hotspots.
  final bool allowsExpensiveNetworkAccess;

  final int maxConnectionsPerHost;

  /// Idle time allowed between packets of a request.
  final Duration requestTimeout;
}
