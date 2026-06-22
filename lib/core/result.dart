/// A failure carried by [Err]. [message] is human-readable; [cause] is the
/// optional underlying error/exception.
class Failure {
  final String message;
  final Object? cause;
  const Failure(this.message, {this.cause});

  @override
  bool operator ==(Object other) => other is Failure && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'Failure($message)';
}

/// A simple success/failure result type used by repository methods that can
/// fail (network, parsing, persistence).
sealed class Result<T> {
  const Result();

  /// Folds this result into a single value of type [R].
  R when<R>({required R Function(T) ok, required R Function(Failure) err});
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);

  @override
  R when<R>({required R Function(T) ok, required R Function(Failure) err}) => ok(value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);

  @override
  R when<R>({required R Function(T) ok, required R Function(Failure) err}) => err(failure);
}
