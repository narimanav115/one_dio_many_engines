import 'dart:typed_data';

/// SignalR binary framing: every message is prefixed with its length
/// encoded as a varint (7 bits per byte, high bit means "more bytes").
abstract final class BinaryMessageFormat {
  static const _maxLengthPrefixSize = 5;

  static Uint8List write(Uint8List message) {
    final prefix = <int>[];
    var size = message.length;

    do {
      var part = size & 0x7f;
      size >>= 7;
      if (size > 0) part |= 0x80;
      prefix.add(part);
    } while (size > 0);

    return Uint8List(prefix.length + message.length)
      ..setRange(0, prefix.length, prefix)
      ..setRange(prefix.length, prefix.length + message.length, message);
  }

  static List<Uint8List> parse(Uint8List input) {
    final messages = <Uint8List>[];
    var offset = 0;

    while (offset < input.length) {
      var size = 0;
      var prefixLength = 0;
      int byte;

      do {
        if (offset + prefixLength >= input.length) {
          throw const FormatException('Cannot read message size.');
        }
        byte = input[offset + prefixLength];
        size |= (byte & 0x7f) << (7 * prefixLength);
        prefixLength++;
      } while ((byte & 0x80) != 0 && prefixLength < _maxLengthPrefixSize);

      if ((byte & 0x80) != 0) {
        throw const FormatException('Cannot read message size.');
      }
      if (prefixLength == _maxLengthPrefixSize && byte > 7) {
        throw const FormatException(
          'Messages bigger than 2 GB are not supported.',
        );
      }

      final start = offset + prefixLength;
      final end = start + size;
      if (end > input.length) {
        throw const FormatException('Incomplete message.');
      }

      messages.add(input.sublist(start, end));
      offset = end;
    }

    return messages;
  }
}
