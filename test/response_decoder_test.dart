import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_dio_many_engines/src/http/response_decoder_io.dart';

void main() {
  final options = RequestOptions(path: '/');
  const body = '{"odds":1.85}';

  ResponseBody responseBody(List<int> bytes, {String? contentType}) =>
      ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          if (contentType != null) Headers.contentTypeHeader: [contentType],
        },
      );

  group('gzipResponseDecoder', () {
    test('inflates a gzip body', () {
      final bytes = gzip.encode(utf8.encode(body));

      expect(
        gzipResponseDecoder(bytes, options, responseBody(bytes)),
        body,
      );
    });

    test('passes a plain body through', () {
      final bytes = utf8.encode(body);

      expect(
        gzipResponseDecoder(bytes, options, responseBody(bytes)),
        body,
      );
    });

    test('returns null for an empty JSON body', () {
      expect(
        gzipResponseDecoder(
          const [],
          options,
          responseBody(const [], contentType: Headers.jsonContentType),
        ),
        isNull,
      );
    });
  });

  group('configureResponseDecoder', () {
    test('asks for gzip only when Http2Adapter is used', () {
      final dio = Dio()
        ..httpClientAdapter = Http2Adapter(ConnectionManager());
      configureResponseDecoder(dio);
      expect(dio.options.headers['accept-encoding'], 'gzip');

      dio.httpClientAdapter = HttpClientAdapter();
      configureResponseDecoder(dio);
      expect(dio.options.headers.containsKey('accept-encoding'), isFalse);
    });
  });
}
