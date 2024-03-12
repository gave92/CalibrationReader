import 'dart:convert';

import 'package:calibration_reader/CalSelector.dart';
import 'package:calibration_reader/FileAcceptType.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:inject_js/inject_js.dart' as js;
import 'package:wasm_ffi/wasm_ffi.dart';
import 'package:wasm_ffi/wasm_ffi_modules.dart';
import 'package:calibration_reader/platform/filesystem_web.dart';

const String _basePath = kReleaseMode ? 'assets/assets' : 'assets';

Module? _module;

Future<void> initFfi() async {
  // Only initalize if there is no module yet
  if (_module == null) {
    Memory.init();

    // Inject the JavaScript into our page
    await js.importLibrary('$_basePath/tinymatwriter.js');

    // Load the WebAssembly binaries from assets
    String path = '$_basePath/tinymatwriter.wasm';
    Uint8List wasmBinaries = (await rootBundle.load(path)).buffer.asUint8List();

    // After we loaded the wasm binaries and injected the js code
    // into our webpage, we obtain a module
    _module = await EmscriptenModule.compile(wasmBinaries, 'tinymatwriter');
  }
}

bool supportsMatExport() => true;

Future<void> exportDcmToMat(List<CalSelector> allCals, String fileName) async {
  if (_module == null) {
    await initFfi();
  }
  if (_module != null) {
    final dylib = DynamicLibrary.fromModule(_module!);
    final open = dylib.lookupFunction<Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)>('TinyMATWriter_open');
    final close = dylib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('TinyMATWriter_close');
    final ftell = dylib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('TinyMATWriter_ftell');
    final data = dylib.lookupFunction<Pointer<Uint8> Function(Pointer<Void>),
        Pointer<Uint8> Function(Pointer<Void>)>('TinyMATWriter_data');
    final write2D = dylib.lookupFunction<
        Void Function(
            Pointer<Void>, Pointer<Utf8>, Pointer<Double>, Int32, Int32),
        void Function(Pointer<Void>, Pointer<Utf8>, Pointer<Double>, int,
            int)>('TinyMATWriter_writeMatrix2D_colmajor_exp_double');
    final outputPath_c = fileName.toNativeUtf8(allocator: dylib.boundMemory);
    final matFile = open(outputPath_c);
    dylib.boundMemory.free(outputPath_c);
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
      final vecp = dylib.boundMemory<Double>(calValue.length);
      for (int ii = 0; ii < calValue.length; ii++) {
        vecp[ii] = calValue[ii];
      }
      final calName_c = cal.name.toNativeUtf8(allocator: dylib.boundMemory);
      write2D(matFile, calName_c, vecp, cal.size[1], cal.size[0]);
      dylib.boundMemory.free(calName_c);
      dylib.boundMemory.free(vecp);
    }
    final bytes = data(matFile).asTypedList(ftell(matFile));
    await saveFileToDevice(fileName, bytes, [
      FileAcceptType({"text/mat": ".mat"}, "MAT file")
    ]);
    close(matFile);
  }
}
