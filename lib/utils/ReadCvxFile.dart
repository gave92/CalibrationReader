import 'dart:async';

import 'package:darq/darq.dart';

Future<(Map<String, List>, List, String, String)> ReadCvxFile(
    StreamIterator<String> lines) async {
  try {
    List<
        ({
          String name,
          String type,
          List<int> size,
          List phys,
          List<String> sst_ref,
          List sst_x,
          List sst_y
        })> calLabels = [];
    Map<String, List> phys = {};
    int numLine = 1;

    if (!await lines.moveNext()) {
      return (phys, calLabels, "", "");
    }
    var firstLine = lines.current.trim();
    var sep = firstLine[23];
    var dec = firstLine[24];
    if ((sep == ',') && (dec == ',')) {
      dec = '.';
    }
    var (com, newStr) = getNextCell(firstLine.substring(26), sep);
    var (dbl_slm, _) = getNextCell(newStr, sep);
    var slm = dbl_slm.isEmpty
        ? '"' // default [e.g. when CVX file was opened with Excel...]
        : dbl_slm[0];

    var currVar = Tuple7<String, String, List<int>, List, List<String>, List,
        List>.fromRecord((
      '',
      '',
      [],
      [],
      <String>[],
      [],
      [],
    ));

    while (await lines.moveNext()) {
      var THIS_l = lines.current.trim();
      numLine = numLine + 1;
      // Check for skipping expressions
      var SKIP = await checkForSkipLines(THIS_l, lines, sep, com);
      numLine += SKIP.$2;
      if (SKIP.$1) {
        continue;
      }
      // Actual content
      var allCells_THIS = getAllCells(THIS_l, sep);
      switch (allCells_THIS[0]) {
        // Records
        case 'VALUE':
          currVar = currVar.copyWith(
              item3: evalCellArray(<dynamic>[allCells_THIS[2]], dec));
          currVar = currVar.copyWith(item1: 'VALUE');
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'CURVE':
          // Skip THIS line
          await lines.moveNext();
          var data_line = lines.current.trim();
          numLine = numLine + 1;
          allCells_THIS = getAllCells(data_line, sep);
          currVar = currVar.copyWith(
              item3: evalCellArray(allCells_THIS.sublist(2), dec));
          currVar = currVar.copyWith(item1: 'CURVE');
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'MAP':
          // Get first data line
          // (skip THIS and NEXT lines)
          await lines.moveNext();
          await lines.moveNext();
          var data_line = lines.current.trim();
          numLine = numLine + 2;
          allCells_THIS = getAllCells(data_line, sep);
          var firstRow = evalCellArray(allCells_THIS.sublist(2), dec);

          // Go through next lines as long as they are not empty
          // (comment, or space-and-separators only)
          var mapMatrix = <dynamic>[firstRow];
          var mapData = true;
          while (mapData) {
            await lines.moveNext();
            data_line = lines.current.trim();
            numLine = numLine + 1;
            // Check if empty line
            SKIP = await checkForSkipLines(data_line, lines, sep, com);
            if (SKIP.$1) {
              // yes: end of map data
              mapData = false;
            } else {
              // no: add line of map data, go on
              allCells_THIS = getAllCells(data_line, sep);
              var THIS_row = evalCellArray(allCells_THIS.sublist(2), dec);
              mapMatrix.add(THIS_row);
            }
          }
          currVar = currVar.copyWith(item3: mapMatrix);
          currVar = currVar.copyWith(item1: 'MAP');
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'CUBOID':
          // Not defined yet...
          break;
        case 'VAL_BLK':
          // TO_BE_CHECKED
          currVar = currVar.copyWith(
              item3: evalCellArray(allCells_THIS.sublist(2), dec));
          currVar = currVar.copyWith(item1: 'VAL_BLK');
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'AXIS_PTS':
        case 'X_AXIS_PTS':
        case 'Y_AXIS_PTS':
        case 'Z_AXIS_PTS':
          currVar = currVar.copyWith(
              item3: evalCellArray(allCells_THIS.sublist(2), dec));
          currVar = currVar.copyWith(item1: allCells_THIS[0]);
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'RESCALE_AXIS_PTS':
          currVar = currVar.copyWith(
              item3: evalCellArray(allCells_THIS.sublist(2), dec));
          currVar = currVar.copyWith(item1: 'RESCALE_AXIS_PTS');
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'ASCII':
          currVar = currVar.copyWith(item3: <dynamic>[
            allCells_THIS[2].substring(1, allCells_THIS[2].length - 2)
          ]);
          currVar = currVar.copyWith(item1: 'ASCII');
          calLabels.add((
            name: currVar.item0,
            type: currVar.item1,
            size: currVar.item2,
            phys: currVar.item3,
            sst_ref: currVar.item4,
            sst_x: currVar.item5,
            sst_y: currVar.item6
          ));
          break;
        case 'FUNCTION':
          //calLabels(end).fcnName  = allCells_THIS{3}(2:end-1);
          //calLabels(end).fcnDescr = allCells_THIS{4}(2:end-1);
          break;
        case 'VARIANT':
          // Variant coding is not resolved!
          //calLabels(end).variant  = allCells_THIS{3};
          break;
        case 'DISPLAY_IDENTIFIER':
          //calLabels(end).dispId  = allCells_THIS{3}(2:end-1);
          break;
        default: // Otherwise: new label
          currVar = Tuple7<String, String, List<int>, List, List<String>, List,
              List>.fromRecord((
            allCells_THIS[1],
            '',
            [],
            [],
            <String>[],
            [],
            [],
          ));
          break;
      }
    }
    return (phys, calLabels, "", "");
  } catch (e) {
    return (<String, List>{}, [], e.toString(), lines.current);
  }
}

(String, String) getNextCell(String str, String sep) {
  int endOfCell = str.indexOf(sep);
  String cellStr = str.substring(0, endOfCell);
  String newStr = str.substring(endOfCell + 1);
  return (cellStr, newStr);
}

List<String> getAllCells(String str, String sep) {
  List<int> sepInds = [];
  int index = 0;
  while (true) {
    int nextIndex = str.indexOf(sep, index);
    if (nextIndex == -1) break;
    sepInds.add(nextIndex);
    index = nextIndex + 1;
  }
  List<String> cellStrs = [];
  int cellStartInd = 0;
  for (int i = 0; i < sepInds.length; i++) {
    cellStrs.add(str.substring(cellStartInd, sepInds[i]));
    cellStartInd = sepInds[i] + 1;
  }
  cellStrs.add(str.substring(cellStartInd));
  return cellStrs;
}

Future<(bool, int)> checkForSkipLines(
    String thisLine, StreamIterator<String> fID, String sep, String com) async {
  int numLine = 0;
  // Regexp expressions skipping lines when starting at index 1:
  List<String> skipExprAt1 = ['FUNCTION_HDR', 'VARIANT_HDR', '\\$com'];
  List<int> skipLines = [2, 2, 1];
  // Regexp expressions skipping lines when no instance found:
  List<String> skipExprEmpty = [
    '[^$sep\\s]'
  ]; // only separators and white spaces

  // Check for skipping expressions
  bool skip = false;
  for (int skpInd = 0; skpInd < skipExprAt1.length; skpInd++) {
    List<RegExpMatch> exprInds =
        RegExp(skipExprAt1[skpInd]).allMatches(thisLine).toList();
    if (exprInds.isNotEmpty) {
      if (exprInds.first.start == 0) {
        // Skip additional lines as applicable
        for (int skpN = 1; skpN < skipLines[skpInd]; skpN++) {
          await fID.moveNext();
          numLine++;
        }
        skip = true;
      }
    }
  }
  for (int skpInd = 0; skpInd < skipExprEmpty.length; skpInd++) {
    if (RegExp(skipExprEmpty[skpInd], caseSensitive: false)
            .firstMatch(thisLine) ==
        null) {
      skip = true;
    }
  }
  return (skip, numLine);
}

List evalCellArray(List cellArray, String dec) {
  int arraySize = cellArray.length;
  List<String> strArray = List.filled(arraySize, '');
  List<double> dblArray = List.filled(arraySize, double.infinity);

  for (int arrayInd = 0; arrayInd < cellArray.length; arrayInd++) {
    dynamic thisElement = cellArray[arrayInd];
    if (thisElement is String && thisElement.startsWith('slm')) {
      // element is a string
      strArray[arrayInd] = thisElement.substring(2, thisElement.length - 1);
    } else {
      // element is (most probably) a numeric value
      if (dec == ',') {
        thisElement = thisElement.replaceAll(',', '.');
      }
      double? numVal =
          double.tryParse(thisElement.toString()); // null if does not eval.
      if (numVal != null) {
        dblArray[arrayInd] = numVal;
      }
    }
  }

  if (dblArray.every((element) => !element.isInfinite)) {
    // All elements are non-string values
    return dblArray;
  } else {
    if (dblArray.length == 1) {
      // just return the string
      return <dynamic>[strArray[0]];
    } else {
      // compile cell from possibly both types of entries
      List result = List.filled(arraySize, null);
      for (int arrayInd = 0; arrayInd < cellArray.length; arrayInd++) {
        if (dblArray[arrayInd].isInfinite) {
          // string
          result[arrayInd] = strArray[arrayInd];
        } else {
          // numeric value
          result[arrayInd] = dblArray[arrayInd];
        }
      }
      return result;
    }
  }
}
