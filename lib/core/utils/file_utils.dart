import 'dart:typed_data';
import 'file_utils_stub.dart'
    if (dart.library.io) 'file_utils_native.dart'
    if (dart.library.html) 'file_utils_web.dart';

Future<Uint8List> readFileAsBytes(String path) => readFileAsBytesImpl(path);
