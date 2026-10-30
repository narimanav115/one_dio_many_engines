import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

import 'apple_session_options.dart';
import 'network_engine.dart';

HttpClientAdapter createHttpClientAdapter(
  NetworkEngine engine, {
  String? proxy,
  AppleSessionOptions apple = const AppleSessionOptions(),
}) => BrowserHttpClientAdapter()..withCredentials = true;
