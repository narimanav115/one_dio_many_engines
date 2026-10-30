import 'package:dio/dio.dart';

import 'response_decoder_io.dart'
    if (dart.library.js_interop) 'response_decoder_web.dart'
    as impl;

/// Makes response decoding match the current adapter.
///
/// Cronet, URLSession and browsers decompress responses themselves.
/// `Http2Adapter` returns raw bytes, so it gets `accept-encoding: gzip`
/// and a decoder that inflates gzip bodies.
///
/// Call it again every time `dio.httpClientAdapter` changes.
void configureResponseDecoder(Dio dio) => impl.configureResponseDecoder(dio);
