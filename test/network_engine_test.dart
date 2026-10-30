import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_dio_many_engines/one_dio_many_engines.dart';

void main() {
  NetworkEngine select(
    TargetPlatform platform, {
    bool isWeb = false,
    bool isGmsAvailable = true,
    String? proxy,
  }) => selectEngine(
    platform: platform,
    isWeb: isWeb,
    isGmsAvailable: isGmsAvailable,
    proxy: proxy,
  );

  test('Android with Google Play Services uses Cronet', () {
    expect(select(TargetPlatform.android), NetworkEngine.cronet);
  });

  test('Android without Google Play Services uses HTTP/2', () {
    expect(
      select(TargetPlatform.android, isGmsAvailable: false),
      NetworkEngine.http2,
    );
  });

  test('iOS and macOS use URLSession', () {
    expect(select(TargetPlatform.iOS), NetworkEngine.cupertino);
    expect(select(TargetPlatform.macOS), NetworkEngine.cupertino);
  });

  test('a proxy wins over the platform default', () {
    expect(
      select(TargetPlatform.android, proxy: '192.168.0.10:8888'),
      NetworkEngine.http2,
    );
    expect(
      select(TargetPlatform.iOS, proxy: '192.168.0.10:8888'),
      NetworkEngine.http2,
    );
  });

  test('an empty proxy is ignored', () {
    expect(select(TargetPlatform.iOS, proxy: ''), NetworkEngine.cupertino);
  });

  test('web always uses the browser', () {
    expect(
      select(TargetPlatform.android, isWeb: true, proxy: 'host:8888'),
      NetworkEngine.browser,
    );
  });

  test('other platforms fall back to HTTP/2', () {
    expect(select(TargetPlatform.linux), NetworkEngine.http2);
    expect(select(TargetPlatform.windows), NetworkEngine.http2);
  });
}
