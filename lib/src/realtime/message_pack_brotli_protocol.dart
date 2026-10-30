import 'dart:convert';
import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:message_pack_dart/message_pack_dart.dart' as msgpack;

import 'binary_message_format.dart';
import 'hub_message.dart';

typedef Decompress = List<int> Function(List<int> bytes);

List<int> _brotliDecode(List<int> bytes) => brotli.decode(bytes);

/// SignalR hub protocol `messagepack+brotli`.
///
/// Same framing and envelope as the standard MessagePack protocol, with one
/// extra `isCompressed` field in front of the payload of Invocation,
/// StreamItem and Completion messages. When the flag is `1`, the payload is
/// Brotli-compressed MessagePack bytes.
///
/// Messages written by the client are never compressed (`isCompressed = 0`):
/// the large payloads go from server to client.
final class MessagePackBrotliProtocol {
  const MessagePackBrotliProtocol({Decompress decompress = _brotliDecode})
    : _decompress = decompress;

  static const name = 'messagepack+brotli';
  static const version = 2;

  final Decompress _decompress;

  /// The JSON handshake a client sends right after the socket opens.
  static String get handshakeRequest =>
      '${jsonEncode({'protocol': name, 'version': version})}\u001e';

  /// Parses one WebSocket frame, which may hold several hub messages.
  /// Unknown message types are skipped, as the SignalR spec requires.
  List<HubMessage> parseMessages(Uint8List input) =>
      BinaryMessageFormat.parse(input).map(_parseMessage).nonNulls.toList();

  Uint8List writeMessage(HubMessage message) {
    final payload = switch (message) {
      InvocationMessage(
        :final headers,
        :final invocationId,
        :final target,
        :final arguments,
      ) =>
        [_MessageType.invocation, headers, invocationId, target, 0, arguments],
      StreamItemMessage(:final headers, :final invocationId, :final item) =>
        [_MessageType.streamItem, headers, invocationId, 0, item],
      CompletionMessage(:final headers, :final invocationId, :final error?) =>
        [
          _MessageType.completion,
          headers,
          invocationId,
          _ResultKind.error,
          0,
          error,
        ],
      CompletionMessage(:final headers, :final invocationId, :final result?) =>
        [
          _MessageType.completion,
          headers,
          invocationId,
          _ResultKind.nonVoid,
          0,
          result,
        ],
      CompletionMessage(:final headers, :final invocationId) =>
        [_MessageType.completion, headers, invocationId, _ResultKind.none],
      PingMessage() => [_MessageType.ping],
      CloseMessage(:final error, :final allowReconnect) =>
        [_MessageType.close, error, allowReconnect],
    };

    return BinaryMessageFormat.write(msgpack.serialize(payload));
  }

  HubMessage? _parseMessage(Uint8List frame) {
    final data = msgpack.deserialize(frame);
    if (data is! List || data.isEmpty || data.first is! int) {
      throw const FormatException('Invalid hub message.');
    }

    return switch (data.first as int) {
      _MessageType.invocation => _invocation(data),
      _MessageType.streamItem => _streamItem(data),
      _MessageType.completion => _completion(data),
      _MessageType.ping => const PingMessage(),
      _MessageType.close => _close(data),
      _ => null,
    };
  }

  InvocationMessage _invocation(List<Object?> data) {
    _requireLength(data, 6, 'Invocation');
    final arguments = _unpack(data[5], isCompressed: data[4] == 1);
    if (arguments is! List) {
      throw const FormatException('Invocation arguments must be a list.');
    }

    return InvocationMessage(
      headers: _headers(data[1]),
      invocationId: data[2] as String?,
      target: data[3]! as String,
      arguments: List<Object?>.of(arguments),
    );
  }

  StreamItemMessage _streamItem(List<Object?> data) {
    _requireLength(data, 5, 'StreamItem');

    return StreamItemMessage(
      headers: _headers(data[1]),
      invocationId: data[2]! as String,
      item: _unpack(data[4], isCompressed: data[3] == 1),
    );
  }

  CompletionMessage _completion(List<Object?> data) {
    _requireLength(data, 4, 'Completion');
    final headers = _headers(data[1]);
    final invocationId = data[2]! as String;
    final kind = data[3];

    if (kind == _ResultKind.none) {
      return CompletionMessage(headers: headers, invocationId: invocationId);
    }

    _requireLength(data, 6, 'Completion');
    final value = _unpack(data[5], isCompressed: data[4] == 1);

    return kind == _ResultKind.error
        ? CompletionMessage(
            headers: headers,
            invocationId: invocationId,
            error: value as String?,
          )
        : CompletionMessage(
            headers: headers,
            invocationId: invocationId,
            result: value,
          );
  }

  CloseMessage _close(List<Object?> data) => CloseMessage(
    error: data.length > 1 ? data[1] as String? : null,
    allowReconnect: data.length > 2 && data[2] == true,
  );

  Object? _unpack(Object? value, {required bool isCompressed}) {
    if (!isCompressed) return value;
    if (value is! List<int>) {
      throw const FormatException('Compressed payload must be binary.');
    }

    return msgpack.deserialize(Uint8List.fromList(_decompress(value)));
  }

  Map<String, String> _headers(Object? raw) => switch (raw) {
    null => const {},
    final Map<Object?, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries) '$key': '$value',
    },
    _ => throw const FormatException('Invalid headers.'),
  };

  void _requireLength(List<Object?> data, int length, String type) {
    if (data.length < length) {
      throw FormatException('Invalid payload for $type message.');
    }
  }
}

abstract final class _MessageType {
  static const invocation = 1;
  static const streamItem = 2;
  static const completion = 3;
  static const ping = 6;
  static const close = 7;
}

abstract final class _ResultKind {
  static const error = 1;
  static const none = 2;
  static const nonVoid = 3;
}
