# one_dio_many_engines

[English](README.md) | 日本語

FlutterKaigi 2026 のセッション **One Dio, Many Engines: Making Flutter Survive Bad Networks** のサンプルコードです。

- 1 つの `Dio` インスタンスで、プラットフォームごとに `HttpClientAdapter` を切り替えます：Cronet、URLSession、純粋な Dart の HTTP/2、またはブラウザ。
- `Dio` を作り直したりインターセプターを失ったりせずに、実行中にアダプターを切り替えられます（例：デバッグ用プロキシへの切り替え）。
- 圧縮されたバイト列をそのまま返す `Http2Adapter` 向けの gzip レスポンスデコーダー。
- SignalR 向けの `messagepack+brotli` ハブプロトコル：MessagePack のフレーミングに Brotli で圧縮したペイロードを組み合わせます。

## 動作要件

- Flutter 3.47 以降、Dart 3.13 以降
- iOS 15 以降、macOS 12 以降（`cupertino_http` 3.x の要件）
- Android API 24 以降（`cronet_http` 1.9 の要件）

## エンジン

| プラットフォーム | エンジン | プロトコル | パッケージ |
| --- | --- | --- | --- |
| Google Play 開発者サービスありの Android | Cronet | HTTP/3 (QUIC)、HTTP/2、Brotli | `cronet_http` |
| iOS、macOS | URLSession | HTTP/3、HTTP/2、HTTP/1.1 | `cupertino_http` |
| GMS なしの Android、デスクトップ | `Http2Adapter` | HTTP/2、HTTP/1.1 にフォールバック | `dio_http2_adapter` |
| デバッグ用プロキシ設定時 | プロキシ付き `Http2Adapter` | HTTP/2、HTTP/1.1 にフォールバック | `dio_http2_adapter` |
| Web | ブラウザ | ブラウザがネゴシエートしたもの | `dio` |

Cronet と URLSession は `dio_compatibility_layer` の `ConversionLayerAdapter` を通じて Dio に接続されるため、インターセプターとトランスフォーマーはどのエンジンでも同じように動作します。

`Http2Adapter` は TLS ハンドシェイク時に `h2` と `http/1.1` の両方を提示します（`supportedProtocols`、`dio_http2_adapter` 2.9.0 で追加）。HTTP/1.1 しか話せないサーバーの中には、`h2` だけを提示されるとハンドシェイクを中断するものがあり、その場合 `fallbackAdapter` は実行されません。

## iOS と macOS

Apple プラットフォームでは、クライアントは `cupertino_http` 経由で URLSession 上で動作します。URLSession はサーバーが `Alt-Svc` で HTTP/3 を通知すると自動で HTTP/3 を選び、HTTP/2 や HTTP/1.1 にフォールバックし、gzip と Brotli をデコードし、システムのプロキシや VPN の設定に従います。

`AppleSessionOptions` で、悪いネットワーク環境向けにセッションを調整できます：

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

| オプション | デフォルト | 内容 |
| --- | --- | --- |
| `waitsForConnectivity` | `false` | 端末がオフラインのとき、すぐに失敗せずネットワークが使えるようになるまで待つ |
| `allowsConstrainedNetworkAccess` | `true` | 省データモードでのリクエストを許可する |
| `allowsExpensiveNetworkAccess` | `true` | モバイル通信やインターネット共有でのリクエストを許可する |
| `maxConnectionsPerHost` | `6` | ホストごとの並列接続数の上限 |
| `requestTimeout` | 20 秒 | リクエストのパケット間で許容されるアイドル時間 |

`waitsForConnectivity` を有効にすると、圏外で発行したリクエストはネットワークが見つかるまで保留されます。バックグラウンド同期やアップロードに向いています。スピナーを表示する画面では無効のままにして、代わりにエラーを表示してください。

URLSession は Multipath TCP（`multipathServiceType`）にも対応しており、接続を切らずに Wi-Fi からモバイル通信へ移行できます。ただし Apple の Multipath エンタイトルメントが必要なため、ここでは有効にしていません。

`CupertinoClient` は、実行中のリクエストが残っている状態でクローズすると例外を投げます。そのため `NetworkClient` はアダプターを切り替えたとき、リクエストタイムアウトが経過してから古いアダプターをクローズします。

## Android

Google Play 開発者サービスがある Android では、クライアントは HTTP/3 (QUIC)、HTTP/2、Brotli を有効にした Cronet 上で動作します。QUIC なら、端末が Wi-Fi から LTE に切り替わっても接続が維持されます。

`CronetEngine.build` には、悪いネットワーク環境で試す価値のあるオプションが他にもあります。たとえば、最初のリクエストから QUIC を使う `quicHints` や、DNS が遅いときや落ちているときにも動き続けるための `enableStaleDns` と `useStaleOnNameNotResolved` です。

## はじめに

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

`isGmsAvailable` はアプリ側から渡します。Android では `google_api_availability` などのパッケージで確認できます。わからない場合は `false` を渡してください。その場合、クライアントは純粋な Dart の HTTP/2 アダプターを使います。

### 実行中にプロキシへ切り替える

```dart
proxy.value = '192.168.0.10:8888'; // Charles、Proxyman、mitmproxy
proxy.value = null;                // プラットフォームのエンジンに戻す
```

同じ `Dio` インスタンスに新しいアダプターが設定されます。古いアダプターはリクエストタイムアウトの経過後にクローズされるので、実行中のリクエストは最後まで完了できます。`client.engine` は `ValueListenable<NetworkEngine>` なので、デバッグ画面に表示できます。

プロキシ用のアダプターはどんな証明書も受け入れるため、プロキシ設定はデバッグビルドでのみ公開してください。

### 部品を個別に使う

```dart
final engine = selectEngine(
  platform: defaultTargetPlatform,
  isWeb: kIsWeb,
  isGmsAvailable: true,
);

dio.httpClientAdapter = createHttpClientAdapter(engine);
configureResponseDecoder(dio);
```

## gzip の落とし穴

`dart:io` の `HttpClient`、Cronet、URLSession、ブラウザはレスポンスを自動で展開します。`Http2Adapter` は展開しません。`Http2Adapter` に切り替えると、gzip のレスポンスがバイナリのまま Dio の JSON トランスフォーマーに届き、パースに失敗します。

`configureResponseDecoder` がこれに対処します：

- `Http2Adapter` を使うときは `accept-encoding: gzip` を送るので、`dart:io` でデコードできない Brotli でサーバーが応答することはありません。
- `gzipResponseDecoder` を設定します。これはボディが gzip のマジックバイトで始まる場合だけ展開し、それ以外はそのまま渡すので、どのエンジンでも安全に使えます。

アダプターを変更するたびに呼び直してください。`NetworkClient` はこれを自動で行います。

## SignalR 向けの MessagePack + Brotli

オッズや株価の更新のようなリアルタイムのペイロードは繰り返しが多く、どのメッセージにも同じキーや名前が含まれます。Brotli はこうしたデータを非常によく圧縮でき、MessagePack はエンベロープをバイナリのまま保ちます。

`MessagePackBrotliProtocol` は標準の SignalR MessagePack プロトコル（varint の長さプレフィックスと MessagePack 配列）に従い、ペイロードの前に `isCompressed` フィールドを 1 つ追加します：

| メッセージ | レイアウト |
| --- | --- |
| Invocation | `[1, headers, invocationId, target, isCompressed, arguments]` |
| StreamItem | `[2, headers, invocationId, isCompressed, item]` |
| Completion | `[3, headers, invocationId, resultKind, isCompressed, result]` |
| Completion（void） | `[3, headers, invocationId, 2]` |
| Ping | `[6]` |
| Close | `[7, error, allowReconnect]` |

`isCompressed` が `1` のとき、ペイロードは Brotli で圧縮した MessagePack バイト列を含む MessagePack の `bin` 値です。`0` のときは通常の MessagePack 値です。クライアントは常に `0` を書き込みます。大きなペイロードはサーバーからクライアントへ流れるものであり、Dart の `brotli` パッケージはデコードしかできないためです。

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

このクラスは SignalR のハブプロトコルと同じ形（`name`、`version`、`parseMessages`、`writeMessage`）をしています。既存の SignalR クライアントで使うには、そのクライアントのハブプロトコルのインターフェースでラップし、転送形式をバイナリに設定してください。

サーバー側では、同じ名前 `messagepack+brotli`、バージョン 2 でハブプロトコルを登録します。あるプラットフォームでデコーダーの問題が見つかったときのために、クライアントを通常の `messagepack` に戻せるリモートフラグを用意しておいてください。

`brotli` は `0.5.0` に固定しています。新しいバージョンでは一部のペイロードのデコードに失敗するためです（[tiagohm/brotli#5](https://github.com/tiagohm/brotli/issues/5)）。

## ベンチマーク

オッズに似たペイロード、1 イベント = 8 マーケット × 3 アウトカム、Brotli 品質 5：

| メッセージ | JSON | MessagePack | MessagePack + Brotli |
| --- | ---: | ---: | ---: |
| 差分、1 イベント | 2.8 KB | 2.0 KB | 0.5 KB |
| ライブ一覧、20 イベント | 54.6 KB | 39.3 KB | 5.4 KB |
| スナップショット、200 イベント | 545.9 KB | 393.4 KB | 49.2 KB |

750 kbit/s の 3G 回線では、200 イベントのスナップショットは JSON で約 5.8 秒、MessagePack + Brotli で 0.5 秒かかります。MessagePack のデコードは JSON より約 1.4〜1.7 倍高速で、Brotli による追加時間は大きなスナップショットでも数ミリ秒です。

再現方法：

```sh
pip install msgpack brotli
python benchmark/payload_size.py
```

## テスト

Flutter のバージョンは `.fvmrc` で固定しています。[FVM](https://fvm.app) を使う場合：

```sh
fvm install
fvm flutter pub get
fvm flutter test
```

FVM を使わない場合は、Flutter 3.47 以降で `fvm` を付けずに同じコマンドを実行してください。

Brotli のテスト用フィクスチャは `benchmark/generate_fixtures.py` で生成しています。

## ライセンス

MIT
