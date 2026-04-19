import 'dart:async';
import 'package:flutter/scheduler.dart';

/// Extension to ensure stream events are delivered on the main UI thread.
/// This prevents "non-platform thread" errors on Windows when Firebase 
/// callbacks arrive from background C++ threads.
extension MainThreadExtension<T> on Stream<T> {
  Stream<T> toMainThread() {
    final controller = StreamController<T>(sync: false);
    StreamSubscription<T>? subscription;

    controller.onListen = () {
      subscription = this.listen(
        (data) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!controller.isClosed) controller.add(data);
          });
        },
        onError: (err) {
          if (!controller.isClosed) controller.addError(err);
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
