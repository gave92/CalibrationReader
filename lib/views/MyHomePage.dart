import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:calibration_reader/models/CalSelector.dart';
import 'package:calibration_reader/models/FileAcceptType.dart';
import 'package:calibration_reader/utils/ReadDcmFile.dart';
import 'package:calibration_reader/utils/ReadCvxFile.dart';
import 'package:calibration_reader/utils/WriteDcmFile.dart';
import 'package:calibration_reader/views/NameValueCalView.dart';
import 'package:calibration_reader/views/ValueEditCalView.dart';
import 'package:collection/collection.dart';
import 'package:darq/darq.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:calibration_reader/platform/filesystem_none.dart'
    if (dart.library.js_interop) 'package:calibration_reader/platform/filesystem_web.dart';
import 'package:calibration_reader/platform/ccode_none.dart'
    if (dart.library.js_interop) 'package:calibration_reader/platform/ccode_web.dart'
    if (dart.library.ffi) 'package:calibration_reader/platform/ccode_windows.dart';

part 'MyHomePage_part_file.dart';

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
  bool showNamesOnly = false;

  PersistentBottomSheetController? _sheetController;
  final _listController = ListController();
  final _scrollController = ScrollController();
  FocusNode? _focusNode;

  SharedPreferences? _prefs;

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
      // Load preferences
      _prefs = await SharedPreferences.getInstance();
      showNamesOnly = _prefs!.getBool('showNamesOnly') ?? false;
      // Open launched file
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
                        Visibility(
                          visible: !filterCals.any((e) => e.isSelected),
                          child: TextButton.icon(
                              onPressed: () => selectFile(
                                  onLoadCallback: loadFileFromStream),
                              icon: const Icon(Icons.add_outlined),
                              label: const Text('Open')),
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
                              !filterCals.any((e) => e.isSelected),
                          child: TextButton.icon(
                              onPressed: () async {
                                setState(() {
                                  showNamesOnly = !showNamesOnly;
                                });
                                await _prefs?.setBool(
                                    'showNamesOnly', showNamesOnly);
                              },
                              icon: const Icon(Icons.view_agenda_outlined),
                              label: const Text('Switch view')),
                        ),
                        Visibility(
                            visible: fileName.isNotEmpty &&
                                !filterCals.any((e) => e.isSelected),
                            child: MenuAnchor(
                              menuChildren: [
                                MenuItemButton(
                                  onPressed: supportsMatExport()
                                      ? exportFileAsMat
                                      : null,
                                  leadingIcon:
                                      const Icon(Icons.import_export_outlined),
                                  child: const Text('Export as MAT'),
                                ),
                                MenuItemButton(
                                    onPressed: showFileInfo,
                                    leadingIcon: const Icon(Icons.info_outline),
                                    child: const Text('Info')),
                                MenuItemButton(
                                    onPressed: () => selectFile(
                                        onLoadCallback: mergeFileFromStream),
                                    leadingIcon:
                                        const Icon(Icons.merge_outlined),
                                    child: const Text('Compare/Merge')),
                              ],
                              builder: (BuildContext context,
                                  MenuController controller, Widget? child) {
                                return TextButton.icon(
                                    onPressed: () {
                                      if (controller.isOpen) {
                                        controller.close();
                                      } else {
                                        controller.open();
                                      }
                                    },
                                    icon: const Icon(Icons.more_horiz_outlined),
                                    label: const Text('More'));
                              },
                            )),
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
                              onPressed: removeCalibration,
                              icon: const Icon(Icons.delete_outlined),
                              label: const Text('Remove')),
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

  Widget nameValueItemBuilder(BuildContext context, int position) {
    final selector = filterCals[position];
    final screenSize = MediaQuery.of(context).size;
    return ListTile(
        onTap: () {
          _sheetController?.close();
          if (filterCals.any((e) => e.isSelected)) {
            setState(() {
              selector.isSelected = !selector.isSelected;
            });
          } else if (showNamesOnly) {
            editCalibration(context, arg: selector);
          }
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
        leading: showNamesOnly
            ? filterCals.any((e) => e.isSelected)
                ? selector.isSelected
                    ? const Icon(Icons.check_box_outlined)
                    : const Icon(Icons.check_box_outline_blank_outlined)
                : selector.calibration.size.any((s) => s == 1)
                    ? const Icon(Icons.data_array_outlined)
                    : const Icon(Icons.grid_3x3_outlined)
            : null,
        visualDensity: const VisualDensity(vertical: -4),
        shape: showNamesOnly
            ? null
            : LinearBorder.bottom(
                size: (screenSize.width - 32) / screenSize.width,
                side: const BorderSide(color: Colors.black26, width: 1)),
        title: showNamesOnly
            ? Text(selector.calibration.name)
            : NameValueCalView(selector: selector));
  }

  void editCalibration(BuildContext context, {CalSelector? arg}) {
    final selector = arg ?? filterCals.firstWhere((e) => e.isSelected);
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
          Flexible(
              child: ListTile(
                  title: ValueEditCalView(
                      selector: selector,
                      onValueEdit: (int row, int col, String value) =>
                          editCalValue(row, col, value, selector)))),
          ListTile(
              title: Row(
            children: [
              TextButton.icon(
                  onPressed: () => copyCalibrationValue(arg: selector),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy value')),
              TextButton.icon(
                  onPressed: () => removeCalibration(arg: [selector]),
                  icon: const Icon(Icons.delete_outlined),
                  label: const Text('Remove'))
            ],
          ))
        ]);
      },
    );
  }

  void editCalValue(int row, int col, String value, CalSelector selector) {
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
  }

  void removeCalibration({List<CalSelector>? arg}) {
    _sheetController?.close();
    final list = arg ?? filterCals.where((e) => e.isSelected).toList();
    setState(() {
      list.forEach((s) => allCals.remove(s));
      list.forEach((s) => filterCals.remove(s));
      isDirty = true;
    });
  }

  void copyCalibrationValue({CalSelector? arg}) async {
    final selector = arg ?? filterCals.firstWhere((e) => e.isSelected);
    final valueText = selector.calibration.phys.firstOrNull is List
        ? selector.calibration.phys
            .map((e) => e as List)
            .map((e) => e
                .map((c) => c is num ? c.toStringAsPrecision(4) : c.toString())
                .join("\t"))
            .join("\r\n")
        : selector.calibration.phys
            .map((c) => c is num ? c.toStringAsPrecision(4) : c.toString())
            .join("\t");
    await Clipboard.setData(ClipboardData(text: valueText));
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
