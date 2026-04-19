import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readFileAsBytesImpl(String path) async {
  return await File(path).readAsBytes();
}
