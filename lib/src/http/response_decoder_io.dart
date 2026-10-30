import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

const _acceptEncoding = 'accept-encoding';

void configureResponseDecoder(Dio dio) {
  if (dio.httpClientAdapter is Http2Adapter) {
    dio.options.headers[_acceptEncoding] = 'gzip';
  } else {
    dio.options.headers.remove(_acceptEncoding);
  }
  dio.options.responseDecoder = gzipResponseDecoder;
}

/// Decodes a response body to a string, inflating it when it is gzip.
///
/// The gzip magic bytes are checked instead of trusting `content-encoding`,
/// so the decoder is safe with engines that already decompressed the body.
/// Returns `null` for an empty JSON body, so Dio does not try to parse `''`.
String? gzipResponseDecoder(
  List<int> responseBytes,
  RequestOptions options,
  ResponseBody responseBody,
) {
  final contentType =
      responseBody.headers[Headers.contentTypeHeader]?.firstOrNull;
  if (responseBytes.isEmpty && Transformer.isJsonMimeType(contentType)) {
    return null;
  }

  final bytes = isGzip(responseBytes)
      ? gzip.decode(responseBytes)
      : responseBytes;

  return utf8.decode(bytes, allowMalformed: true);
}

bool isGzip(List<int> bytes) =>
    bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
