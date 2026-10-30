# one_dio_many_engines

English | [日本語](README.ja.md)

Example code for the FlutterKaigi 2026 talk **One Dio, Many Engines: Making Flutter Survive Bad Networks**.

- One `Dio` instance, with the `HttpClientAdapter` picked per platform: Cronet, URLSession, pure Dart HTTP/2 or the browser.
- Switch the adapter at runtime (for example to a debugging proxy) without recreating `Dio` or losing interceptors.
- A gzip response decoder for `Http2Adapter`, which returns compressed bytes as is.
- A `messagepack+brotli` hub protocol for SignalR: MessagePack framing with Brotli-compressed payloads.

## Requirements

- Flutter 3.47 or newer, Dart 3.13 or newer
- iOS 15 or newer, macOS 12 or newer (required by `cupertino_http` 3.x)
- Android API 24 or newer (required by `cronet_http` 1.9)

## Engines

| Platform | Engine | Protocols | Package |
| --- | --- | --- | --- |
| Android with Google Play Services | Cronet | HTTP/3 (QUIC), HTTP/2, Brotli | `cronet_http` |
| iOS, macOS | URLSession | HTTP/3, HTTP/2, HTTP/1.1 | `cupertino_http` |
| Android without GMS, desktop | `Http2Adapter` | HTTP/2, falls back to HTTP/1.1 | `dio_http2_adapter` |
| Debug proxy set | `Http2Adapter` with proxy | HTTP/2, falls back to HTTP/1.1 | `dio_http2_adapter` |
| Web | Browser | whatever the browser negotiates | `dio` |

Cronet and URLSession are plugged into Dio through `ConversionLayerAdapter` from `dio_compatibility_layer`, so interceptors and transformers work the same on every engine.

`Http2Adapter` offers both `h2` and `http/1.1` during the TLS handshake (`supportedProtocols`, added in `dio_http2_adapter` 2.9.0). Some servers that only speak HTTP/1.1 abort the handshake when only `h2` is offered, and then `fallbackAdapter` never runs.

## iOS and macOS

On Apple platforms the client runs on URLSession through `cupertino_http`. URLSession picks HTTP/3 by itself when the server advertises it with `Alt-Svc`, falls back to HTTP/2 and HTTP/1.1, decodes gzip and Brotli, and follows the system proxy and VPN settings.

The session can be tuned for bad networks with `AppleSessionOptions`:

```dart
final client = NetworkClient(
  baseUrl: 'https://api.example.com',
  isGmsAvailable: false,
  apple: const AppleSessionOptions(
    waitsForConnectivity: true,
    allowsConstrainedNetworkAccess: true,
    requestTimeout: Duration(seconds: 30),
  ),
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `waitsForConnectivity` | `false` | Waits for a network instead of failing at once when the device is offline |
| `allowsConstrainedNetworkAccess` | `true` | Allows requests in Low Data Mode |
| `allowsExpensiveNetworkAccess` | `true` | Allows requests over cellular and personal hotspots |
| `maxConnectionsPerHost` | `6` | Upper limit of parallel connections per host |
| `requestTimeout` | 20 s | Idle time allowed between packets of a request |

With `waitsForConnectivity` on, a request made in a dead zone stays pending until a network appears. That suits background syncs and uploads. For a screen that shows a spinner, keep it off and show an error instead.

URLSession also supports Multipath TCP (`multipathServiceType`), which can move a connection from Wi-Fi to cellular without breaking it. It needs the Multipath entitlement from Apple, so it is not enabled here.

`CupertinoClient` throws if it is closed while requests are still running. When the adapter is swapped, `NetworkClient` closes the old one only after the request timeout has passed.

## Android

On Android with Google Play Services the client runs on Cronet with HTTP/3 (QUIC), HTTP/2 and Brotli enabled. QUIC also keeps a connection alive when the device moves from Wi-Fi to LTE.

`CronetEngine.build` has more options worth trying on bad networks, for example `quicHints` to start with QUIC on the first request, and `enableStaleDns` with `useStaleOnNameNotResolved` to keep working when DNS is slow or down.

## Getting started

```yaml
dependencies:
  one_dio_many_engines:
    git:
      url: https://github.com/narimanav115/one_dio_many_engines
```

```dart
final proxy = ValueNotifier<String?>(null);

final client = NetworkClient(
  baseUrl: 'https://api.example.com',
  isGmsAvailable: await hasGooglePlayServices(),
  proxy: proxy,
  interceptors: [AuthInterceptor(), LogInterceptor()],
);

final response = await client.dio.get('/events');
```

`isGmsAvailable` comes from your app. On Android you can check it with a package such as `google_api_availability`. Pass `false` if you are not sure: the client then uses the pure Dart HTTP/2 adapter.

### Switching to a proxy at runtime

```dart
proxy.value = '192.168.0.10:8888'; // Charles, Proxyman, mitmproxy
proxy.value = null;                // back to the platform engine
```

The same `Dio` instance gets a new adapter. The old adapter is closed after the request timeout, so in-flight requests can finish. `client.engine` is a `ValueListenable<NetworkEngine>` you can show on a debug screen.

The proxy adapter accepts any certificate, so only expose the proxy setting in debug builds.

### Using the pieces separately

```dart
final engine = selectEngine(
  platform: defaultTargetPlatform,
  isWeb: kIsWeb,
  isGmsAvailable: true,
);

dio.httpClientAdapter = createHttpClientAdapter(engine);
configureResponseDecoder(dio);
```

## The gzip gotcha

`dart:io` `HttpClient`, Cronet, URLSession and browsers decompress responses for you. `Http2Adapter` does not. Once you switch to it, a gzip response reaches Dio's JSON transformer as binary and parsing fails.

`configureResponseDecoder` handles this:

- with `Http2Adapter`, it sends `accept-encoding: gzip`, so the server never answers with Brotli, which `dart:io` cannot decode;
- it installs `gzipResponseDecoder`, which inflates the body when it starts with the gzip magic bytes and passes it through otherwise, so it is safe with every engine.

Call it again after every adapter change. `NetworkClient` does that for you.

## MessagePack + Brotli for SignalR

Real-time payloads such as odds or stock updates are repetitive: the same keys and names in every message. Brotli compresses them very well, and MessagePack keeps the envelope binary.

`MessagePackBrotliProtocol` follows the standard SignalR MessagePack protocol (varint length prefix, MessagePack arrays) and adds one `isCompressed` field in front of the payload:

| Message | Layout |
| --- | --- |
| Invocation | `[1, headers, invocationId, target, isCompressed, arguments]` |
| StreamItem | `[2, headers, invocationId, isCompressed, item]` |
| Completion | `[3, headers, invocationId, resultKind, isCompressed, result]` |
| Completion, void | `[3, headers, invocationId, 2]` |
| Ping | `[6]` |
| Close | `[7, error, allowReconnect]` |

When `isCompressed` is `1`, the payload is a MessagePack `bin` value with Brotli-compressed MessagePack bytes inside. When it is `0`, the payload is a plain MessagePack value. The client always writes `0`: the large payloads travel from server to client, and the Dart `brotli` package only decodes.

```dart
const protocol = MessagePackBrotliProtocol();

socket.add(MessagePackBrotliProtocol.handshakeRequest);

socket.listen((frame) {
  if (frame is! Uint8List) return;
  for (final message in protocol.parseMessages(frame)) {
    if (message case StreamItemMessage(:final item)) onOdds(item);
  }
});

socket.add(protocol.writeMessage(
  const InvocationMessage(target: 'Subscribe', arguments: ['football']),
));
```

The class has the same shape as a SignalR hub protocol (`name`, `version`, `parseMessages`, `writeMessage`). To use it with an existing SignalR client, wrap it in that client's hub protocol interface and set the transfer format to binary.

On the server, register a hub protocol with the same name, `messagepack+brotli`, and version 2. Keep a remote flag that switches clients back to plain `messagepack` in case a decoder issue shows up on one platform.

`brotli` is pinned to `0.5.0` because newer versions fail to decode some payloads ([tiagohm/brotli#5](https://github.com/tiagohm/brotli/issues/5)).

## Benchmarks

Odds-like payloads, one event = 8 markets × 3 outcomes, Brotli quality 5:

| Message | JSON | MessagePack | MessagePack + Brotli |
| --- | ---: | ---: | ---: |
| Delta, 1 event | 2.8 KB | 2.0 KB | 0.5 KB |
| Live list, 20 events | 54.6 KB | 39.3 KB | 5.4 KB |
| Snapshot, 200 events | 545.9 KB | 393.4 KB | 49.2 KB |

On a 750 kbit/s 3G link the 200-event snapshot takes about 5.8 s as JSON and 0.5 s as MessagePack + Brotli. MessagePack decodes about 1.4 to 1.7x faster than JSON; Brotli adds a few milliseconds on a large snapshot.

Reproduce:

```sh
pip install msgpack brotli
python benchmark/payload_size.py
```

## Tests

The Flutter version is pinned in `.fvmrc`. With [FVM](https://fvm.app):

```sh
fvm install
fvm flutter pub get
fvm flutter test
```

Without FVM, use Flutter 3.47 or newer and run the same commands without `fvm`.

The Brotli test fixtures are generated by `benchmark/generate_fixtures.py`.

## License

MIT
