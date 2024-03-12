import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:calibration_reader/CalSelector.dart';
import 'package:calibration_reader/Editable.dart';
import 'package:calibration_reader/FileAcceptType.dart';
import 'package:calibration_reader/ReadDcmFile.dart';
import 'package:calibration_reader/WriteDcmFile.dart';
import 'package:collection/collection.dart';
import 'package:darq/darq.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:calibration_reader/platform/filesystem_none.dart'
    if (dart.library.js_interop) 'package:calibration_reader/platform/filesystem_web.dart';
import 'package:calibration_reader/platform/ccode_none.dart'
    if (dart.library.js_interop) 'package:calibration_reader/platform/ccode_web.dart'
    if (dart.library.ffi) 'package:calibration_reader/platform/ccode_windows.dart';

// flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 --web-renderer canvaskit
void main(List<String> args) {
  runApp(CalRearder(args: args));
}

class CalRearder extends StatelessWidget {
  final List<String> args;

  const CalRearder({super.key, required this.args});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calibration Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Calibration Reader', args: args),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.args});

  final List<String> args;
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool showErr = false;
  String errMessage = "";
  String fileName = "";
  List<CalSelector> allCals = [], filterCals = [];
  bool isDirty = false;

  PersistentBottomSheetController? _sheetController;
  final _listController = ListController();
  final _scrollController = ScrollController();
  FocusNode? _focusNode;

  Future<void> selectFile() async {
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
      await loadFileFromStream(stream, result.files.first.name);
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
    });
  }

  void showFileInfo() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              title: Text(fileName),
              subtitle: Text("${filterCals.length} calibrations"))
        ]);
      },
    );
  }

  void runFilter(String value) {
    var results = allCals;
    if (value.isNotEmpty) {
      final pattern =
          RegExp(value.replaceAll("*", ".*?"), caseSensitive: false);
      results =
          results.where((e) => pattern.hasMatch(e.calibration.name)).toList();
    }
    setState(() {
      filterCals = results;
    });
  }

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.keyboard.addHandler(onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.args.isNotEmpty) {
        final file = File(widget.args.first);
        final stream = StreamIterator(file
            .openRead()
            .transform(latin1.decoder)
            .transform(const LineSplitter()));
        await loadFileFromStream(stream, path.basename(file.path));
      } else if (supportsLaunchQueue()) {
        setLaunchQueueConsumer(onLoadCallback: loadFileFromStream);
      }
    });
    _focusNode = FocusNode();
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return DropTarget(
        onDragDone: dropFile,
        child: Scaffold(
          body: CustomScrollView(controller: _scrollController, slivers: [
            SliverAppBar(
              floating: screenSize.height < 400,
              pinned: true,
              snap: false,
              centerTitle: false,
              title: Text(widget.title),
              actions: const [],
              bottom: AppBar(
                automaticallyImplyLeading: false,
                title: Container(
                  width: double.infinity,
                  height: 40,
                  color: Colors.white,
                  child: Center(
                    child: TextField(
                        onChanged: (value) => runFilter(value),
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(4),
                            hintText: 'Search',
                            suffixIcon: Icon(Icons.search))),
                  ),
                ),
              ),
            ),
            showErr
                ? SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverFillRemaining(
                      child: Text(errMessage),
                    ),
                  )
                : filterCals.isNotEmpty
                    ? SuperSliverList(
                        delegate: SliverChildBuilderDelegate(
                          nameValueItemBuilder,
                          childCount: filterCals.length,
                        ),
                        listController: _listController)
                    : const SliverFillRemaining(child: SizedBox.shrink())
          ]),
          floatingActionButton: null,
          bottomNavigationBar: BottomAppBar(
            height: 60,
            child: Container(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: selectFile,
                          icon: const Icon(Icons.add_outlined),
                          label: const Text('Open'),
                        ),
                        Visibility(
                          visible: fileName.isNotEmpty &&
                              !filterCals.any((e) => e.isSelected),
                          child: TextButton.icon(
                              onPressed: showFileInfo,
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Info')),
                        ),
                        Visibility(
                          visible: fileName.isNotEmpty &&
                              !filterCals.any((e) => e.isSelected) &&
                              isDirty,
                          child: TextButton.icon(
                              onPressed: saveFile,
                              icon: const Icon(Icons.save_as_outlined),
                              label: const Text('Save')),
                        ),
                        Visibility(
                          visible: fileName.isNotEmpty &&
                              !filterCals.any((e) => e.isSelected) &&
                              supportsMatExport(),
                          child: TextButton.icon(
                              onPressed: exportFileAsMat,
                              icon: const Icon(Icons.import_export_outlined),
                              label: const Text('Export as MAT')),
                        ),
                        Visibility(
                          visible: filterCals.any((e) => e.isSelected),
                          child: TextButton.icon(
                              onPressed: copyCalibrationName,
                              onLongPress: copyCalibrationValue,
                              icon: const Icon(Icons.copy_all_outlined),
                              label: const Text('Copy')),
                        ),
                        Visibility(
                          visible: filterCals.count((e) => e.isSelected) == 1,
                          child: LayoutBuilder(builder: (BuildContext context,
                              BoxConstraints constraints) {
                            return TextButton.icon(
                                onPressed: () => editCalibration(context),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'));
                          }),
                        ),
                        Visibility(
                          visible: filterCals.any((e) => e.isSelected),
                          child: TextButton.icon(
                              onPressed: saveFileSelected,
                              icon: const Icon(Icons.save_as_outlined),
                              label: const Text('Save selected')),
                        ),
                      ],
                    ))),
          ),
        ));
  }

  Widget showCalValue(dynamic calValue, int length, double maxWidth) {
    final textValue =
        calValue is num ? calValue.toStringAsPrecision(4) : calValue.toString();
    double desWidth = math.min(math.max(70, maxWidth / length), 100);
    return Container(
        alignment: Alignment.center,
        width: desWidth,
        padding: const EdgeInsets.only(left: 6, right: 6),
        child: Text(textValue));
  }

  Widget editCalValue(int row, int col, dynamic calValue, CalSelector selector,
      int length, double maxWidth) {
    final textValue =
        calValue is num ? calValue.toStringAsPrecision(4) : calValue.toString();
    double desWidth = math.min(math.max(70, maxWidth / length), 100);
    return Editable(
      text: textValue,
      width: desWidth,
      onSubmitted: (value) {
        if (row >= 0) {
          setState(() {
            (selector.calibration.phys[row] as List)[col] = double.parse(value);
            isDirty = true;
          });
        } else {
          setState(() {
            selector.calibration.phys[col] = double.parse(value);
            isDirty = true;
          });
        }
      },
    );
  }

  Widget nameValueItemBuilder(BuildContext context, int position) {
    var appTheme = Theme.of(context);
    final selector = filterCals[position];
    final cal = selector.calibration;
    final screenSize = MediaQuery.of(context).size;
    return ListTile(
        onTap: () {
          _sheetController?.close();
          if (filterCals.any((e) => e.isSelected)) {
            setState(() {
              selector.isSelected = !selector.isSelected;
            });
          } else {}
        },
        onLongPress: () {
          _sheetController?.close();
          if (!filterCals.any((e) => e.isSelected)) {
            setState(() {
              selector.isSelected = !selector.isSelected;
            });
          } else if (selector.isSelected) {
            final selectAll = !filterCals.all((e) => e.isSelected);
            setState(() {
              filterCals.forEach((e) => e.isSelected = selectAll);
            });
          }
        },
        selected: selector.isSelected,
        shape: LinearBorder.bottom(
            size: (screenSize.width - 32) / screenSize.width,
            side: const BorderSide(color: Colors.black26, width: 1)),
        title: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(cal.name,
                    style: appTheme.textTheme.titleMedium!.copyWith(
                        color: selector.isSelected
                            ? appTheme.primaryColor
                            : null)),
                cal.phys.firstOrNull is List
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          Column(
                              children: cal.phys
                                  .map((e) => e as List)
                                  .map(
                                    (e) => Row(
                                      children: e
                                          .map((c) => showCalValue(c, e.length,
                                              constraints.maxWidth))
                                          .toList(),
                                    ),
                                  )
                                  .toList()),
                          cal.sst_ref.length > 1
                              ? RotatedBox(
                                  quarterTurns: 1,
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minWidth: 100,
                                          maxWidth: math.max(
                                              100, cal.phys.length * 17)),
                                      child: Text(
                                        cal.sst_ref[1],
                                        textAlign: TextAlign.center,
                                      )))
                              : const SizedBox.shrink(),
                        ]))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: cal.phys
                                .map((c) => showCalValue(
                                    c, cal.phys.length, constraints.maxWidth))
                                .toList())),
                cal.sst_ref.isNotEmpty
                    ? Text(cal.sst_ref[0])
                    : const SizedBox.shrink(),
              ]);
        }));
  }

  void editCalibration(BuildContext context) {
    final selector = filterCals.firstWhere((e) => e.isSelected);
    final cal = selector.calibration;
    _sheetController = showBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              title: Text(selector.calibration.name),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _sheetController?.close(),
              )),
          Flexible(child: ListTile(title: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: cal.phys.firstOrNull is List
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                            children: cal.phys
                                .map((e) => e as List)
                                .mapIndexed(
                                  (row, e) => Row(
                                    children: e
                                        .mapIndexed((col, c) => editCalValue(
                                            row,
                                            col,
                                            c,
                                            selector,
                                            e.length,
                                            constraints.maxWidth))
                                        .toList(),
                                  ),
                                )
                                .toList()))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: cal.phys
                                .mapIndexed((col, c) => editCalValue(
                                    -1,
                                    col,
                                    c,
                                    selector,
                                    cal.phys.length,
                                    constraints.maxWidth))
                                .toList())));
          }))),
          ListTile(
              title: Row(
            children: [
              TextButton.icon(
                  onPressed: copyCalibrationValue,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy value')),
              TextButton.icon(
                  onPressed: removeCalibration,
                  icon: const Icon(Icons.delete_outlined),
                  label: const Text('Remove'))
            ],
          ))
        ]);
      },
    );
  }

  void removeCalibration() {
    _sheetController?.close();
    setState(() {
      allCals.removeWhere((e) => e.isSelected && filterCals.contains(e));
      filterCals.removeWhere((e) => e.isSelected);
      isDirty = true;
    });
  }

  void copyCalibrationValue() async {
    final calibs = filterCals.where((e) => e.isSelected);
    if (calibs.length == 1) {
      final valueText = calibs.first.calibration.phys.firstOrNull is List
          ? calibs.first.calibration.phys
              .map((e) => e as List)
              .map((e) => e
                  .map(
                      (c) => c is num ? c.toStringAsPrecision(4) : c.toString())
                  .join("\t"))
              .join("\r\n")
          : calibs.first.calibration.phys
              .map((c) => c is num ? c.toStringAsPrecision(4) : c.toString())
              .join("\t");
      await Clipboard.setData(ClipboardData(text: valueText));
    }
  }

  void copyCalibrationName() async {
    final calibs = filterCals.where((e) => e.isSelected);
    await Clipboard.setData(ClipboardData(
        text: calibs.map((c) => c.calibration.name).join("\r\n")));
  }

  bool onKey(KeyEvent event) {
    final key = event.logicalKey.keyId;
    if (event is KeyDownEvent) {
      final focus = FocusManager.instance.primaryFocus;
      if (_focusNode != focus && !filterCals.any((e) => e.isSelected)) {
        if (key >= 97 && key <= 122) {
          // A-Z
          final jumpItemIndex = filterCals.indexWhere((e) => e.calibration.name
              .toLowerCase()
              .startsWith(event.logicalKey.keyLabel.toLowerCase()));
          if (jumpItemIndex >= 0) {
            _listController.jumpToItem(
              index: jumpItemIndex,
              scrollController: _scrollController,
              alignment: 0,
            );
          }
        }
      }
    }
    return false;
  }
}
