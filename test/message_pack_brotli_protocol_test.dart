import 'package:flutter_test/flutter_test.dart';
import 'package:one_dio_many_engines/one_dio_many_engines.dart';

import 'fixtures.dart';

void main() {
  const protocol = MessagePackBrotliProtocol();

  Map<String, Object?> asMap(Object? value) =>
      Map<String, Object?>.from(value! as Map);

  void expectOdds(Object? value) {
    final odds = asMap(value);
    expect(odds['eventId'], 1001);
    expect(odds['home'], 'Team A');

    final market = asMap((odds['markets']! as List).single);
    expect(market['name'], 'Total 2.5');
    expect((market['outcomes']! as List).length, 2);
  }

  test('handshake names the protocol', () {
    expect(
      MessagePackBrotliProtocol.handshakeRequest,
      '{"protocol":"messagepack+brotli","version":2}\u001e',
    );
  });

  test('decodes a compressed stream item', () {
    final message = protocol.parseMessages(streamItemCompressed).single;

    expect(message, isA<StreamItemMessage>());
    message as StreamItemMessage;
    expect(message.invocationId, '1');
    expectOdds(message.item);
  });

  test('reads a plain stream item without touching Brotli', () {
    final protocol = MessagePackBrotliProtocol(
      decompress: (_) => fail('must not decompress'),
    );

    final message =
        protocol.parseMessages(streamItemPlain).single as StreamItemMessage;

    expectOdds(message.item);
  });

  test('decodes compressed invocation arguments and headers', () {
    final message =
        protocol.parseMessages(invocationCompressed).single
            as InvocationMessage;

    expect(message.target, 'OddsUpdated');
    expect(message.invocationId, isNull);
    expect(message.headers, {'trace': 'abc'});
    expectOdds(message.arguments.single);
  });

  test('decodes a compressed completion result', () {
    final message =
        protocol.parseMessages(completionCompressed).single
            as CompletionMessage;

    expect(message.invocationId, '2');
    expect(message.error, isNull);
    expectOdds(message.result);
  });

  test('decodes a void completion', () {
    final message =
        protocol.parseMessages(completionVoid).single as CompletionMessage;

    expect(message.invocationId, '3');
    expect(message.result, isNull);
    expect(message.error, isNull);
  });

  test('parses a batch and skips unknown message types', () {
    final messages = protocol.parseMessages(batch);

    expect(messages, [isA<PingMessage>(), isA<StreamItemMessage>()]);
  });

  test('writes messages it can read back', () {
    const outgoing = [
      InvocationMessage(
        target: 'Subscribe',
        arguments: ['football', 42],
        invocationId: '7',
      ),
      CompletionMessage(invocationId: '8', result: 'ok'),
      CompletionMessage(invocationId: '9', error: 'boom'),
      PingMessage(),
    ];

    for (final message in outgoing) {
      final parsed = protocol
          .parseMessages(protocol.writeMessage(message))
          .single;
      expect(parsed.runtimeType, message.runtimeType);
    }

    final invocation =
        protocol.parseMessages(protocol.writeMessage(outgoing.first)).single
            as InvocationMessage;
    expect(invocation.target, 'Subscribe');
    expect(invocation.arguments, ['football', 42]);
  });
}
