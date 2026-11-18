import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:isolate';

/// Extension to ensure stream events are delivered on the main UI thread.
/// This prevents "non-platform thread" errors on Windows desktop streams.
extension MainThreadExtension<T> on Stream<T> {
  Stream<T> toMainThread() {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return this; // Return original stream on Mobile/Web.
    }

    final controller = StreamController<T>.broadcast(sync: false);
    StreamSubscription<T>? subscription;
    ReceivePort? receivePort;

    void closePort() {
      receivePort?.close();
      receivePort = null;
    }

    // The port is opened per listen, not once. Cached streams (watch helpers)
    // are handed back to a new StreamBuilder when a tab is revisited; the old
    // receive port was closed on cancel, so reusing it would silently drop
    // every event and leave the UI loading forever.
    controller.onListen = () {
      if (receivePort != null) return;
      final port = ReceivePort();
      receivePort = port;

      // By opening the ReceivePort here on the setup thread (Main thread), it
      // guarantees we receive the events natively on this isolate.
      port.listen((message) {
        if (message is _StreamError) {
          if (!controller.isClosed) {
            controller.addError(message.error, message.stackTrace);
          }
        } else if (message is _StreamDone) {
          if (!controller.isClosed) controller.close();
          closePort();
        } else {
          if (!controller.isClosed) controller.add(message as T);
        }
      });

      final sendPort = port.sendPort;
      subscription = listen(
        (data) {
          sendPort.send(data);
        },
        onError: (e, st) {
          sendPort.send(_StreamError(e, st));
        },
        onDone: () {
          sendPort.send(const _StreamDone());
        },
      );
    };

    controller.onCancel = () {
      subscription?.cancel();
      subscription = null;
      closePort();
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
