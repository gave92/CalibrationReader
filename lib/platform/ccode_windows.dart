import 'dart:ffi';
import 'dart:io';
import 'package:calibration_reader/CalSelector.dart';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

bool supportsMatExport() => Platform.isWindows;

String getLibPath() {
  if (kReleaseMode) {
    // I'm on release mode, absolute linking
    final String local_lib = path.join(
        'data', 'flutter_assets', 'assets', 'TinyMATShared_Release.dll');
    return path.join(
        Directory(Platform.resolvedExecutable).parent.path, local_lib);
  } else {
    // I'm on debug mode, local linking
    final path = Directory.current.path;
    return '$path/assets/TinyMATShared_Release.dll';
  }
}

Future<String?> getOutputPath(String fileName) async {
  String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: fileName,
      allowedExtensions: [".mat", ".MAT"]);
  return outputPath;
}

Future<void> exportDcmToMat(List<CalSelector> allCals, String fileName) async {
  final outputPath = await getOutputPath(fileName);
  if (outputPath == null) {
    return;
  }
  final dylib = DynamicLibrary.open(getLibPath());
  final open = dylib.lookupFunction<Pointer<Void> Function(Pointer<Utf8>),
      Pointer<Void> Function(Pointer<Utf8>)>('TinyMATWriter_open');
  final close = dylib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('TinyMATWriter_close');
  final write2D = dylib.lookupFunction<
      Void Function(
          Pointer<Void>, Pointer<Utf8>, Pointer<Double>, Int32, Int32),
      void Function(Pointer<Void>, Pointer<Utf8>, Pointer<Double>, int,
          int)>('TinyMATWriter_writeMatrix2D_colmajor_exp_double');
  final outputPath_c = outputPath.toNativeUtf8();
  final matFile = open(outputPath_c);
  malloc.free(outputPath_c);
  if (matFile == nullptr) {
    return;
  }
  for (final cal in allCals.map((e) => e.calibration)) {
    final calValue = cal.phys.firstOrNull is List
        ? cal.phys
            .map((e) => e as List)
            .expand((e) => e.map((v) => v is num ? v.toDouble() : 0.0))
            .toList(growable: false)
        : cal.phys
            .map((v) => v is num ? v.toDouble() : 0.0)
            .toList(growable: false);
    final vecp = malloc<Double>(calValue.length);
    for (int ii = 0; ii < calValue.length; ii++) {
      vecp[ii] = calValue[ii];
    }
    final calName_c = cal.name.toNativeUtf8();
    write2D(matFile, calName_c, vecp, cal.size[1], cal.size[0]);
    malloc.free(calName_c);
    malloc.free(vecp);
  }
  close(matFile);
}
