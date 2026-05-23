import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:isolate';

/// Extension to ensure stream events are delivered on the main UI thread.
/// This prevents "non-platform thread" errors on Windows when Firebase 
/// callbacks arrive from background C++ threads.
extension MainThreadExtension<T> on Stream<T> {
  Stream<T> toMainThread() {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return this; // Return original stream on Mobile/Web so Firestore cache resolves synchronously
    }

    final controller = StreamController<T>.broadcast(sync: false);
    StreamSubscription<T>? subscription;

    // By opening the ReceivePort here on the setup thread (Main thread), 
    // it guarantees we receive the events natively on this isolate.
    final mainIsolatePort = ReceivePort();

    mainIsolatePort.listen((message) {
       if (message is _StreamError) {
         if (!controller.isClosed) controller.addError(message.error, message.stackTrace);
       } else if (message is _StreamDone) {
         if (!controller.isClosed) controller.close();
         mainIsolatePort.close();
       } else {
         if (!controller.isClosed) controller.add(message as T);
       }
    });

    controller.onListen = () {
      final SendPort mainIsolateSendPort = mainIsolatePort.sendPort;
      subscription = listen(
        (data) {
          mainIsolateSendPort.send(data);
        },
        onError: (e, st) {
          mainIsolateSendPort.send(_StreamError(e, st));
        },
        onDone: () {
          mainIsolateSendPort.send(const _StreamDone());
        },
      );
    };

    controller.onCancel = () {
      subscription?.cancel();
      mainIsolatePort.close();
    };

    return controller.stream;
  }
}

class _StreamError {
  final dynamic error;
  final StackTrace? stackTrace;
  _StreamError(this.error, this.stackTrace);
}
class _StreamDone {
  const _StreamDone();
}
