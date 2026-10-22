/// Result of an operation that can fail, returned by repositories instead of
/// throwing across layers (house standard: Async & Errors).
sealed class Result<T> {
  const Result();

  /// The value for [Ok], null for [Error].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Error<T>() => null,
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Error<T> extends Result<T> {
  const Error(this.error);
  final Exception error;
}

/// Runs [body] and turns a thrown [Exception] into [Error]. Programming
/// errors ([Error] subclasses of dart:core) are not caught: they reach the
/// global handlers in main.dart.
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Exception catch (e) {
    return Error(e);
  }
}
