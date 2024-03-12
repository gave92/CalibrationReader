import 'dart:async';

import 'package:darq/darq.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

String? WriteDcmFile(List<dynamic> input) {
  //try {
  final info = input.cast<
      ({
        String name,
        List phys,
        List<int> size,
        List sst_ref,
        List sst_x,
        List sst_y,
        String type
      })>();
  final buffer = StringBuffer();
  buffer.write(sprintf('%s\r\n', [getHeader()]));
  buffer.write(sprintf('%s\r\n', [getfunktionen(info)]));
  for (int f = 0; f < info.length; f++) {
    if (info[f].phys.isNotEmpty && info[f].phys.all((e) => e != null)) {
      // Skip invalid cals
      String str_var = getVariable(info[f]);
      if (str_var.isNotEmpty) {
        buffer.write(sprintf('%s\r\n', [str_var]));
      }
    }
  }
  return buffer.toString();
  //} catch (e) {
  //return null;
  //}
}

String getHeader() {
  final DateFormat formatter = DateFormat.yMd().add_Hms();
  String header = [
    '* encoding="ISO-8859-1"',
    '* DAMOS format',
    '* Created by mat2dcm',
    sprintf('* Creation date: %s', [formatter.format(DateTime.now())]),
    '*',
    '* Project: ',
    '* Dataset: ',
    '',
    'KONSERVIERUNG_FORMAT 2.0',
    ''
  ].join(sprintf('\r\n', []));
  return header;
}

String getfunktionen(
    List<
            ({
              String name,
              List phys,
              List<int> size,
              List sst_ref,
              List sst_x,
              List sst_y,
              String type
            })>
        info) {
  String funktionen = ['FUNKTIONEN', '', 'END', ''].join(sprintf('\r\n', []));
  return funktionen;
}

String getVariable(
    ({
      String name,
      List phys,
      List<int> size,
      List sst_ref,
      List sst_x,
      List sst_y,
      String type
    }) info) {
  String header;
  String value;
  if (info.size[0] == 1) {
    header = '${info.type} ${info.name} ${info.size[1]}';
  } else {
    header =
        '${info.type} ${info.name} ${info.size.map((e) => e.toString()).join(' ')}';
  }
  switch (info.type) {
    case 'FESTWERT':
    case 'FESTWERTEBLOCK':
      value = get1DStrValue(info.phys, 'WERT');
      break;
    case 'FESTKENNLINIE':
    case 'GRUPPENKENNLINIE':
      var stx = get1DStrValue(List.filled(info.size[1], 0), 'ST/X');
      value = get1DStrValue(info.phys, 'WERT');
      value = '${stx}\r\n${value}';
      break;
    case 'FESTKENNFELD':
    case 'GRUPPENKENNFELD':
      var stx = get1DStrValue(List.filled(info.size[0], 0), 'ST/X');
      List<String> tmpValue = [stx];
      for (var col = 0; col < info.phys.length; col++) {
        var sty = get1DStrValue(0, 'ST/Y');
        tmpValue.add(sty);
        tmpValue.add(get1DStrValue(info.phys[col], 'WERT'));
      }
      value = tmpValue.join('\r\n');
      break;
    case 'STUETZSTELLENVERTEILUNG':
      value = get1DStrValue(info.phys, 'ST/X');
      break;
    default:
      print('Unsupported type: ${info.type} -> ${info.name}');
      value = "";
  }
  return '${header}\r\n${value}\r\nEND\r\n';
}

String get1DStrValue(dynamic phys, String prefix) {
  String value;
  if (phys is List && phys.all((e) => e is num)) {
    phys = phys.map((e) => e.toString()).toList();
    value = '${prefix} ${phys.join(' ')}';
  } else if (phys is num) {
    phys = phys.toString();
    value = '${prefix} ${phys}';
  } else if (phys is List && phys.all((e) => e is bool)) {
    phys = phys.map((e) => e.toString()).toList();
    value = 'TEXT ${phys.map((e) => '"${e}"').join(' ')}';
  } else if (phys is String) {
    value = 'TEXT "${phys}"';
  } else if (phys is List && phys.all((e) => e is String)) {
    value = 'TEXT ${phys.map((e) => '"${e}"').join(' ')}';
  } else {
    print('Unsupported class: ${phys.runtimeType}');
    value = '';
  }
  return value;
}

String logical2str(bool value) {
  return switch (value) { true => 'TRUE', _ => 'FALSE' };
}
