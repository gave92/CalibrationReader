import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:calibration_reader/FileAcceptType.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

void loadFileFromLaunchQueue(List<web.FileSystemFileHandle> handles,
    {required Future<void> Function(StreamIterator<String> stream, String name)
        onLoadCallback}) async {
  if (handles.isNotEmpty) {
    final file = await handles.first.getFile().toDart as web.File;
    final contents = await file.text().toDart as String;
    final stream = StreamIterator(
        Stream.fromIterable(const LineSplitter().convert(contents)));
    await onLoadCallback(stream, file.name);
  }
}

void setLaunchQueueConsumer(
    {required Future<void> Function(StreamIterator<String> stream, String name)
        onLoadCallback}) {
  web.window.launchQueue.setConsumer((web.LaunchParams launchParams) {
    final handles = launchParams.files.toDart.cast<web.FileSystemFileHandle>();
    loadFileFromLaunchQueue(handles, onLoadCallback: onLoadCallback);
  }.toJS);
}

bool supportsLaunchQueue() => web.window.hasProperty('launchQueue'.toJS).toDart;
bool supportsSaveFilePicker() =>
    web.window.hasProperty('showSaveFilePicker'.toJS).toDart;

Future<bool> saveFileToDevice(
    String fileName, Uint8List bytes, List<FileAcceptType> extensions) async {
  if (supportsSaveFilePicker()) {
    try {
      var options = web.SaveFilePickerOptions(suggestedName: fileName);
      options.excludeAcceptAllOption = true;
      options.types = extensions
          .map((e) => web.FilePickerAcceptType(
              description: e.description,
              accept: (() {
                final accept = JSObjectType();
                e.extensions.forEach((key, value) {
                  accept[key] = value.toJS;
                });
                return accept;
              })()))
          .toList(growable: false)
          .toJS;
      options.startIn = "documents".toJS;
      final handle = await web.window.showSaveFilePicker(options).toDart
          as web.FileSystemFileHandle;
      final stream = await handle.createWritable().toDart
          as web.FileSystemWritableFileStream;
      await stream.write(bytes.toJS).toDart;
      await stream.close().toDart;
      return true;
    } catch (e) {
      print("User dismissed file picker dialog: ${e.toString()}");
      return false;
    }
  } else {
    await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: "", // fileName includes extension
        mimeType: MimeType.text);
    return true;
  }
}

@JS()
@staticInterop
@anonymous
class JSObjectType implements JSObject {
  external factory JSObjectType();
}
