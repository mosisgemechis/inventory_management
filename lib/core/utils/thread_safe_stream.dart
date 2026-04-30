import 'dart:async';

/// Extension to ensure stream events are delivered on the main UI thread.
/// This prevents "non-platform thread" errors on Windows when Firebase 
/// callbacks arrive from background C++ threads.
extension MainThreadExtension<T> on Stream<T> {
  Stream<T> toMainThread() {
    final controller = StreamController<T>.broadcast(sync: false);
    StreamSubscription<T>? subscription;

    controller.onListen = () {
      subscription = listen(
        (data) {
          // Use Timer(Duration.zero) to ensure immediate dispatch to the main event loop
          // which is more robust on Windows than post-frame callbacks for data delivery.
          Future.delayed(Duration.zero, () {
            if (!controller.isClosed) controller.add(data);
          });
        },
        onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
        },
      );
    };

    controller.onCancel = () {
      subscription?.cancel();
    };

    return controller.stream;
  }
}
