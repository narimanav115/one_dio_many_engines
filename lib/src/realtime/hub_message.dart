/// The subset of SignalR hub messages a client usually needs.
sealed class HubMessage {
  const HubMessage({this.headers = const {}});

  final Map<String, String> headers;
}

final class InvocationMessage extends HubMessage {
  const InvocationMessage({
    required this.target,
    required this.arguments,
    this.invocationId,
    super.headers,
  });

  final String target;
  final List<Object?> arguments;
  final String? invocationId;
}

final class StreamItemMessage extends HubMessage {
  const StreamItemMessage({
    required this.invocationId,
    required this.item,
    super.headers,
  });

  final String invocationId;
  final Object? item;
}

final class CompletionMessage extends HubMessage {
  const CompletionMessage({
    required this.invocationId,
    this.result,
    this.error,
    super.headers,
  });

  final String invocationId;
  final Object? result;
  final String? error;
}

final class PingMessage extends HubMessage {
  const PingMessage();
}

final class CloseMessage extends HubMessage {
  const CloseMessage({this.error, this.allowReconnect = false});

  final String? error;
  final bool allowReconnect;
}
