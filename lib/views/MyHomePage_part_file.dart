part of 'MyHomePage.dart';

extension _MyHomePageStateFile on _MyHomePageState {
  Future<void> selectFile(
      {required Future<void> Function(
              StreamIterator<String> stream, String name)
          onLoadCallback}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dcm', 'DCM'],
        withData: false,
        withReadStream: true);
    if (result != null) {
      var stream = StreamIterator(result.files.first.readStream!
          .transform(latin1.decoder)
          .transform(const LineSplitter()));
      //final fc = latin1.decode(result.files.first.bytes!.toList());
      await onLoadCallback(stream, result.files.first.name);
    }
  }

  Future<void> dropFile(DropDoneDetails drop) async {
    var stream = StreamIterator(drop.files.first
        .openRead()
        .cast<List<int>>()
        .transform(latin1.decoder)
        .transform(const LineSplitter()));
    await loadFileFromStream(stream, drop.files.first.name);
  }

  Future<void> loadFileFromStream(
      StreamIterator<String> stream, String name) async {
    var (_, calibs, err, line) = await ReadDcmFile(stream);
    setState(() {
      showErr = err.isNotEmpty;
      errMessage = "$err: $line";
      allCals = calibs
          .map((e) => CalSelector(e))
          .sortedBy((e) => e.calibration.name)
          .toList();
      filterCals = allCals;
      fileName = name;
      isDirty = false;
    });
  }

  Future<void> mergeFileFromStream(
      StreamIterator<String> stream, String name) async {
    var (_, calibs, err, _) = await ReadDcmFile(stream);
    if (err.isNotEmpty) return;
    final ids = <String>{};
    setState(() {
      allCals = [...calibs.map((e) => CalSelector(e)), ...allCals] // Keep newer
          .where((e) => ids.add(e.calibration.name))
          .sortedBy((e) => e.calibration.name);
      filterCals = allCals;
      isDirty = true;
    });
  }

  Future<void> exportFileAsMat() async {
    if (supportsMatExport()) {
      await exportDcmToMat(
          allCals, "${path.basenameWithoutExtension(fileName)}.mat");
    }
  }

  Future<void> saveFile() async {
    final dcmString = WriteDcmFile(allCals.map((e) => e.calibration).toList());
    if (dcmString == null) {
      print("Error writing DCM to string");
      return;
    }
    final wasSaved =
        await saveFileToDevice(fileName, latin1.encode(dcmString), [
      FileAcceptType({"text/dcm": ".dcm"}, "DCM file")
    ]);
    if (wasSaved) {
      setState(() {
        isDirty = false;
      });
    }
  }

  Future<void> saveFileSelected() async {
    final dcmString = WriteDcmFile(
        allCals.where((e) => e.isSelected).map((e) => e.calibration).toList());
    if (dcmString == null) {
      print("Error writing DCM to string");
      return;
    }
    await saveFileToDevice(fileName, latin1.encode(dcmString), [
      FileAcceptType({"text/dcm": ".dcm"}, "DCM file")
    ]);
  }
}
