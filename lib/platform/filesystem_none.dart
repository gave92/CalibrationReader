import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:calibration_reader/FileAcceptType.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

void setLaunchQueueConsumer(
    {required Future<void> Function(StreamIterator<String> stream, String name)
        onLoadCallback}) {}

bool supportsLaunchQueue() => false;

Future<bool> saveFileToDevice(
    String fileName, Uint8List bytes, List<FileAcceptType> extensions) async {
  try {
    String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: fileName,
        allowedExtensions: extensions
            .expand((e) => e.extensions.values)
            .toList(growable: false));
    if (outputPath != null) {
      await File(outputPath).writeAsBytes(bytes, flush: true);
      return true;
    }
  } on UnimplementedError {
    await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: "", // fileName includes extension
        mimeType: MimeType.text);
    return true;
  }
  return false;
}
