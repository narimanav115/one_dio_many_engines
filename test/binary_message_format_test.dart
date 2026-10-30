import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_dio_many_engines/one_dio_many_engines.dart';

void main() {
  Uint8List bytes(int length) =>
      Uint8List.fromList(List.generate(length, (i) => i % 256));

  test('one-byte length prefix for short messages', () {
    final framed = BinaryMessageFormat.write(bytes(10));

    expect(framed.first, 10);
    expect(framed.length, 11);
  });

  test('multi-byte length prefix for long messages', () {
    final framed = BinaryMessageFormat.write(bytes(300));

    expect(framed.sublist(0, 2), [0xAC, 0x02]);
    expect(BinaryMessageFormat.parse(framed).single, bytes(300));
  });

  test('parses several messages from one frame', () {
    final input = Uint8List.fromList([
      ...BinaryMessageFormat.write(bytes(3)),
      ...BinaryMessageFormat.write(bytes(200)),
    ]);

    final messages = BinaryMessageFormat.parse(input);

    expect(messages.map((m) => m.length), [3, 200]);
  });

  test('throws on a truncated message', () {
    final framed = BinaryMessageFormat.write(bytes(20));

    expect(
      () => BinaryMessageFormat.parse(framed.sublist(0, 10)),
      throwsFormatException,
    );
  });
}
