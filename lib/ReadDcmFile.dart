import 'dart:async';

Future<(Map<String, List>, List, String, String)> ReadDcmFile(
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
        })> info = [];
    Map<String, List> phys = {};
    int lnCount = 1;

    while (await lines.moveNext()) {
      var tline = lines.current.trim();
      if (tline == '*') {
        // skip
      } else if (tline.startsWith('* ')) {
        // skip
      } else if (tline.startsWith('KONSERVIERUNG_FORMAT')) {
        double version = double.parse(tline.split(RegExp(r"\s+"))[1]);
        print('DCM version: $version');
      } else if (tline.startsWith('FUNKTIONEN')) {
        // skip
      } else if (tline.startsWith('END')) {
        // skip
      } else if (tline.contains('FKT ')) {
        // skip
      } else if (tline.startsWith('FESTWERT ')) {
        String varname = tline.split(RegExp(r"\s+"))[1];
        dynamic value;

        while (tline != 'END') {
          if (tline.contains('WERT')) {
            value = double.tryParse(tline.split(RegExp(r"\s+"))[1]);
          }
          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = [value];
        final currVar = (
          name: varname,
          type: 'FESTWERT',
          size: [1, 1],
          phys: [value],
          sst_ref: <String>[],
          sst_x: [],
          sst_y: [],
        );
        info.add(currVar);
      } else if (tline.startsWith('FESTKENNLINIE ')) {
        List<String?> toks = RegExp(r'FESTKENNLINIE\s+([\w\.]+)\s+(\d+)')
            .firstMatch(tline)!
            .groups([1, 2]);
        String varname = toks[0]!;
        int size = int.parse(toks[1]!);
        List value = [];
        List sst_x = [];

        while (tline != 'END') {
          if (tline.contains('WERT')) {
            value.addAll(RegExp(r'WERT\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
          } else if (tline.contains('ST/X')) {
            sst_x.addAll(RegExp(r'ST/X\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
          }
          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = value;
        final currVar = (
          name: varname,
          type: 'FESTKENNLINIE',
          size: [1, size],
          phys: value,
          sst_ref: <String>[],
          sst_x: sst_x,
          sst_y: [],
        );
        info.add(currVar);
      } else if (tline.startsWith('FESTWERTEBLOCK ')) {
        // vettore
        RegExp exp = RegExp(r'FESTWERTEBLOCK\s+([\w\.]+)\s+(\d+)');
        List<String?> toks = exp.firstMatch(tline)!.groups([1, 2]);
        String varname = toks[0]!;
        int size = int.parse(toks[1]!);
        List value = [];

        while (tline != 'END') {
          if (tline.contains('WERT')) {
            value.addAll(RegExp(r'WERT\s+(.+)')
                    .firstMatch(tline)
                    ?.group(1)!
                    .split(RegExp(r"\s+"))
                    .map(double.parse) ??
                []);
          }
          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = value;

        final currVar = (
          name: varname,
          type: 'FESTWERTEBLOCK',
          size: [1, size],
          phys: value,
          sst_ref: <String>[],
          sst_x: [],
          sst_y: [],
        );

        info.add(currVar);
      } else if (tline.startsWith('FESTKENNFELD ')) {
        // matrice
        RegExp exp = RegExp(r'FESTKENNFELD ([\w\.]+)\s+(\d+)\s+(\d+)');
        List<String?> toks = exp.firstMatch(tline)!.groups([1, 2, 3]);
        String varname = toks[0]!;
        int size = int.parse(toks[1]!);
        List<List<double>> value = [];
        List<double> temp = [];
        List<double> sst_x = [];
        List<double> sst_y = [];

        while (tline != 'END') {
          if (tline.contains('WERT')) {
            temp.addAll(RegExp(r'WERT\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
            if (temp.length == size) {
              value.add(temp);
              temp = [];
            }
          } else if (tline.contains('ST/X')) {
            sst_x.addAll(RegExp(r'ST/X\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
          } else if (tline.contains('ST/Y')) {
            sst_y.addAll(RegExp(r'ST/Y\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
          }
          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = value;

        final currVar = (
          name: varname,
          type: 'FESTKENNFELD',
          size: [size, int.parse(toks[2]!)],
          phys: value,
          sst_ref: <String>[],
          sst_x: sst_x,
          sst_y: sst_y,
        );

        info.add(currVar);
      } else if (tline.startsWith('GRUPPENKENNLINIE ')) {
        // lookup 1d
        RegExp exp = RegExp(r'GRUPPENKENNLINIE\s+([\w\.]+)\s+(\d+)');
        List<String?> toks = exp.firstMatch(tline)!.groups([1, 2]);
        String varname = toks[0]!;
        int size = int.parse(toks[1]!);
        List<double> value = [];
        List<double> sst_x = [];
        List<String> sst_ref = [];

        while (tline != 'END') {
          if (tline.contains('WERT')) {
            value.addAll(RegExp(r'WERT\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
          } else if (tline.contains('ST/X')) {
            sst_x.addAll(RegExp(r'ST/X\s+(.+)')
                .firstMatch(tline)!
                .group(1)!
                .split(RegExp(r"\s+"))
                .map(double.parse));
          } else if (tline.contains('*SSTX')) {
            sst_ref.add(tline.split(RegExp(r"\s+"))[1]);
          }
          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = value;

        final currVar = (
          name: varname,
          type: 'GRUPPENKENNLINIE',
          size: [1, size],
          phys: value,
          sst_y: [],
          sst_ref: sst_ref,
          sst_x: sst_x,
        );

        info.add(currVar);
      } else if (tline.startsWith('GRUPPENKENNFELD ')) {
        // lookup 2d
        List<String?> toks =
            RegExp(r'GRUPPENKENNFELD\s+([\w\.]+)\s+(\d+)\s+(\d+)')
                .firstMatch(tline)!
                .groups([1, 2, 3]);
        String varname = toks[0]!;
        int size = int.parse(toks[1]!);
        List<List<double>> value = [];
        List<double> temp = [];
        List<double> sst_x = [];
        List<double> sst_y = [];
        List<String> sst_ref = [];

        while (tline != 'END') {
          if (tline.contains('WERT')) {
            temp.addAll(tline
                .substring(5)
                .split(RegExp(r"\s+"))
                .where((e) => e.isNotEmpty)
                .map((e) => double.parse(e)));
            if (temp.length == size) {
              value.add(temp);
              temp = [];
            }
          } else if (tline.contains('ST/X')) {
            sst_x.addAll(tline
                .substring(5)
                .split(RegExp(r"\s+"))
                .where((e) => e.isNotEmpty)
                .map((e) => double.parse(e)));
          } else if (tline.contains('ST/Y')) {
            sst_y.addAll(tline
                .substring(5)
                .split(RegExp(r"\s+"))
                .where((e) => e.isNotEmpty)
                .map((e) => double.parse(e)));
          } else if (tline.contains('*SSTX')) {
            sst_ref.add(tline.substring(6));
          } else if (tline.contains('*SSTY')) {
            sst_ref.add(tline.substring(6));
          }

          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = value;
        final currVar = (
          name: varname,
          type: 'GRUPPENKENNFELD',
          size: [size, int.parse(toks[2]!)],
          phys: value,
          sst_ref: sst_ref,
          sst_x: sst_x,
          sst_y: sst_y
        );
        info.add(currVar);
      } else if (tline.startsWith('STUETZSTELLENVERTEILUNG ')) {
        List<String?> toks =
            RegExp(r'STUETZSTELLENVERTEILUNG\s+([\w\.]+)\s+(\d+)')
                .firstMatch(tline)!
                .groups([1, 2]);
        String varname = toks[0]!;
        int size = int.parse(toks[1]!);
        List<double> value = [];

        while (tline != 'END') {
          if (tline.contains('ST/X')) {
            value.addAll(tline
                .substring(5)
                .split(RegExp(r"\s+"))
                .where((e) => e.isNotEmpty)
                .map((e) => double.parse(e)));
          }

          lnCount++;
          await lines.moveNext();
          tline = lines.current.trim();
        }

        phys[varname] = value;
        final currVar = (
          name: varname,
          type: 'STUETZSTELLENVERTEILUNG',
          size: [1, size],
          phys: value,
          sst_ref: <String>[],
          sst_x: [],
          sst_y: []
        );
        info.add(currVar);
      } else if (tline.isNotEmpty) {
        print('Invalid line: $tline ($lnCount)');
      }

      lnCount++;
    }

    return (phys, info, "", "");
  } catch (e) {
    return (<String, List>{}, [], e.toString(), lines.current);
  }
}

/*
import 'dart:async';

Future<Map<String, List>> ReadDcmFile(StreamIterator<String> lines) async {
  List<({String name, String type, List<int> size, List phys, List sst_ref, List sst_x, List sst_y})> info = [];
  Map<String, List> phys = {};
  int infoIndex = 0;
  int lnCount = 1;

  while (await lines.moveNext()) {
    var tline = lines.current.trim();
    if (tline == '*') {
      // skip
    } else if (tline.startsWith('* ')) {
      // skip
    } else if (tline.startsWith('KONSERVIERUNG_FORMAT')) {
      double version = double.parse(tline.split(RegExp(r"\s+"))[1]);
      print('DCM version: $version');
    } else if (tline.startsWith('FUNKTIONEN')) {
      // skip
    } else if (tline.startsWith('END')) {
      // skip
    } else if (tline.contains('FKT ')) {
      // skip
    } else if (tline.startsWith('FESTWERT ')) {
      String varname = tline.split(RegExp(r"\s+"))[1];
      dynamic value;

      while (tline != 'END') {
        if (tline.contains('WERT')) {
          value = double.parse(tline.split(RegExp(r"\s+"))[1]);
        } else if (tline.contains('TEXT')) {
          value = tline.trim().split(RegExp(r"\s+"))[1].replaceAll('"', '');
          value = getValueFromText(value);
        }
        lnCount++;
        await lines.moveNext();
        tline = lines.current.trim();
      }

      phys[varname] = value;
      final currVar = (
        name: varname,
        type: 'FESTWERT',
        size: [1, 1],
        phys: [value],
        sst_ref: [],
        sst_x: [],
        sst_y: [],
      );
      info[infoIndex++] = currVar;
    } else if (tline.startsWith('FESTKENNLINIE ')) {
      List<String?> toks = RegExp(r'FESTKENNLINIE\s+([\w\.]+)\s+(\d+)').firstMatch(tline)!.groups([1, 2]);
      String varname = toks[0]!;
      int size = int.parse(toks[1]!);
      List value = [];
      List sst_x = [];

      while (tline != 'END') {
        if (tline.contains('WERT')) {
          value.addAll(RegExp(r'WERT\s+(.+)').firstMatch(tline)!.group(1)!.split(RegExp(r"\s+")).map(double.parse));
        } else if (tline.contains('TEXT')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)!).toList();
          value.addAll(strValue.map((str) => getValueFromText(str)));
          if (!value.every((element) => element is String)) {
            value = value.map((e) => double.parse(e)).toList();
          }
        } else if (tline.contains('ST/X')) {
          sst_x.addAll(RegExp(r'ST/X\s+(.+)').firstMatch(tline)?.group(1).split(RegExp(r"\s+")).map(double.parse));
        } else if (tline.contains('ST_TX/X')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)).toList();
          sst_x.addAll(strValue.map((str) => getValueFromText(str)));
          if (!sst_x.every((element) => element is String)) {
            sst_x = sst_x.map((e) => double.parse(e)).toList();
          }
        }
        lnCount++;
        tline = fgetl(fid);
      }

      phys[varname] = value;
      Map<String, dynamic> currVar = {
        'name': toks[0],
        'type': 'FESTKENNLINIE',
        'size': [1, size],
        'phys': value,
        'sst_ref': null,
        'sst_y': null,
      };
      currVar['sst_x'] = sst_x;
      infoIndex++;
      info[infoIndex] = currVar;
    }
    else if (tline.startsWith('FESTWERTEBLOCK ')) {
      // vettore
      RegExp exp = RegExp(r'FESTWERTEBLOCK ([\w\.]+) (\d+)');
      List<RegExpMatch> matches = exp.allMatches(tline).toList();
      List<String> toks = matches[0].group(1).split(RegExp(r"\s+"));
      String varname = toks[0];
      int size = int.parse(toks[1]);
      List value = [];

      while (tline != 'END') {
        if (tline.contains('WERT')) {
          value.addAll(sscanf(strtrim(tline), 'WERT %s', List.filled(size, '%f')));
        } else if (tline.contains('TEXT')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)).toList();
          value.addAll(strValue.map((text) => getValueFromText(text)));
          if (!(value is List<String>)) {
            value = value.cast<num>();
          }
        }
        lnCount++;
        tline = fgetl(fid);
      }

      phys[varname] = value;

      Map<String, dynamic> currVar = {
        'name': toks[0],
        'type': 'FESTWERTEBLOCK',
        'size': [1, size],
        'phys': value,
        'sst_ref': [],
        'sst_x': [],
        'sst_y': [],
      };

      infoIndex++;
      info.add(currVar);
    } else if (tline.startsWith('FESTKENNFELD ')) {
      // matrice
      RegExp exp = RegExp(r'FESTKENNFELD ([\w\.]+)\s+(\d+)\s+(\d+)');
      List<RegExpMatch> matches = exp.allMatches(tline).toList();
      List<String> toks = matches[0].group(1).split(RegExp(r"\s+"));
      String varname = toks[0];
      int size = int.parse(toks[1]);
      List<List<num>> value = [];
      List<num> temp = [];
      List<num> sst_x = [];
      List<num> sst_y = [];

      while (tline != 'END') {
        if (tline.contains('WERT')) {
          temp.addAll(sscanf(strtrim(tline), 'WERT %s', List.filled(size, '%f')));
          if (temp.length == int.parse(toks[2])) {
            value.add(temp);
            temp = [];
          }
        } else if (tline.contains('TEXT')) {
          print('Not supported: $varname (${strtrim(tline)})');
        } else if (tline.contains('ST/X')) {
          sst_x.addAll(sscanf(strtrim(tline), 'ST/X %s', List.filled(size, '%f')));
        } else if (tline.contains('ST/Y')) {
          sst_y.addAll(sscanf(strtrim(tline), 'ST/Y %s', List.filled(size, '%f')));
        } else if (tline.contains('ST_TX/X')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)).toList();
          sst_x.addAll(strValue.map((text) => getValueFromText(text)));
          if (!(sst_x is List<String>)) {
            sst_x = sst_x.cast<num>();
          }
        } else if (tline.contains('ST_TX/Y')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)).toList();
          sst_y.addAll(strValue.map((text) => getValueFromText(text)));
          if (!(sst_y is List<String>)) {
            sst_y = sst_y.cast<num>();
          }
        }
        lnCount++;
        tline = fgetl(fid);
      }

      phys[varname] = value;

      Map<String, dynamic> currVar = {
        'name': toks[0],
        'type': 'FESTKENNFELD',
        'size': [int.parse(toks[1]), int.parse(toks[2])],
        'phys': value,
        'sst_ref': [],
        'sst_x': sst_x,
        'sst_y': sst_y,
      };

      infoIndex++;
      info.add(currVar);
    } else if (tline.startsWith('GRUPPENKENNLINIE ')) {
      // lookup 1d
      RegExp exp = RegExp(r'GRUPPENKENNLINIE\s+([\w\.]+)\s+(\d+)');
      List<RegExpMatch> matches = exp.allMatches(tline).toList();
      List<String> toks = matches[0].group(1).split(RegExp(r"\s+"));
      String varname = toks[0];
      int size = int.parse(toks[1]);
      List<num> value = [];
      List<num> sst_x = [];
      List<String> sst_ref = [];

      while (tline != 'END') {
        if (tline.contains('WERT')) {
          value.addAll(sscanf(strtrim(tline), 'WERT %s', List.filled(size, '%f')));
        } else if (tline.contains('TEXT')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)).toList();
          value.addAll(strValue.map((text) => getValueFromText(text)));
          if (!(value is List<String>)) {
            value = value.cast<num>();
          }
        } else if (tline.contains('ST/X')) {
          sst_x.addAll(sscanf(strtrim(tline), 'ST/X %s', List.filled(size, '%f')));
        } else if (tline.contains('*SSTX')) {
          sst_ref.addAll(sscanf(strtrim(tline), '*SSTX %s'));
        } else if (tline.contains('ST_TX/X')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((match) => match.group(1)).toList();
          sst_x.addAll(strValue.map((text) => getValueFromText(text)));
          if (!(sst_x is List<String>)) {
            sst_x = sst_x.cast<num>();
          }
        }
        lnCount++;
        tline = fgetl(fid);
      }

      phys[varname] = value;

      Map<String, dynamic> currVar = {
        'name': toks[0],
        'type': 'GRUPPENKENNLINIE',
        'size': [1, size],
        'phys': value,
        'sst_y': [],
        'sst_ref': sst_ref,
        'sst_x': sst_x,
      };

      infoIndex++;
      info.add(currVar);
    }
    elseif (tline.startsWith('GRUPPENKENNFELD ')) {
      // lookup 2d
      List<String> toks = RegExp(r'GRUPPENKENNFELD\s+([\w\.]+)\s+(\d+)\s+(\d+)')
          .firstMatch(tline)
          .groups([1, 2, 3]);
      String varname = toks[0].replaceAll('.', '_');
      int size = int.parse(toks[1]);
      List<double> temp = [];

      while (tline != 'END') {
        if (tline.contains('WERT')) {
          temp.addAll(
              tline.trim().substring(5).split(RegExp(r"\s+")).map((e) => double.parse(e)));
          if (temp.length == int.parse(toks[1])) {
            value.add([...temp]);
            temp.clear();
          }
        } else if (tline.contains('TEXT')) {
          print('Not supported: $varname (${tline.trim()})');
        } else if (tline.contains('ST/X')) {
          sst_x.addAll(tline.trim().substring(5).split(RegExp(r"\s+")).map((e) => double.parse(e)));
        } else if (tline.contains('ST/Y')) {
          sst_y.addAll(tline.trim().substring(5).split(RegExp(r"\s+")).map((e) => double.parse(e)));
        } else if (tline.contains('*SSTX')) {
          sst_ref.add(tline.trim().substring(6));
        } else if (tline.contains('*SSTY')) {
          sst_ref.add(tline.trim().substring(6));
        } else if (tline.contains('ST_TX/X')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((e) => e.group(1)).toList();
          sst_x.addAll(strValue.map((e) => getValueFromText(e)));
        } else if (tline.contains('ST_TX/Y')) {
          List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((e) => e.group(1)).toList();
          sst_y.addAll(strValue.map((e) => getValueFromText(e)));
        }

        lnCount++;
        tline = fid.readLineSync();
      }

      phys[varname] = value;
      Map<String, dynamic> currVar = {
        'name': toks[0],
        'type': 'GRUPPENKENNFELD',
        'size': [int.parse(toks[1]), int.parse(toks[2]),
        'phys': value,
        'sst_ref': sst_ref,
        'sst_x': sst_x,
        'sst_y': sst_y
      };
      infoIndex++;
      info.add(currVar);
    } else if (tline.startsWith('STUETZSTELLENVERTEILUNG ')) {
  List<String> toks = RegExp(r'STUETZSTELLENVERTEILUNG\s+([\w\.]+)\s+(\d+)')
      .firstMatch(tline)
      .groups([1, 2]);
  String varname = toks[0].replaceAll('.', '_');
  int size = int.parse(toks[1]);
  List<double> value = [];

  while (tline != 'END') {
  if (tline.contains('ST/X')) {
  value.addAll(tline.trim().substring(5).split(RegExp(r"\s+")).map((e) => double.parse(e)));
  } else if (tline.contains('ST_TX/X')) {
  List<String> strValue = RegExp(r'"(.*?)"').allMatches(tline).map((e) => e.group(1)).toList();
  value.addAll(strValue.map((e) => getValueFromText(e)));
  }

  lnCount++;
  tline = fid.readLineSync();
  }

  phys[varname] = value;
  Map<String, dynamic> currVar = {
  'name': toks[0],
  'type': 'STUETZSTELLENVERTEILUNG',
  'size': [1, int.parse(toks[1])],
  'phys': value,
  'sst_ref': [],
  'sst_x': [],
  'sst_y': []
  };
  infoIndex++;
  info.add(currVar);
  } else if (tline.isNotEmpty) {
  print('Invalid line: $tline ($lnCount)');
  }

  lnCount++;
  }

  info.removeRange(infoIndex + 1, info.length);

  if (file.existsSync()) {
  file.deleteSync();
  }

  if (varargout.length == 0) {
  File('${dcmFile.replaceAll(RegExp(r'(?i)\.dcm$'), '.mat')}').writeAsStringSync(phys.toString());
  } else if (varargout.length == 1) {
  varargout.add(phys);
  } else if (varargout.length == 2) {
  varargout.add(phys);
  varargout.add(info);
  }
}

/// Function to get value from text
dynamic getValueFromText(String strValue) {
  if (strValue.toLowerCase() == 'false') {
    return false;
  } else if (strValue.toLowerCase() == 'true') {
    return true;
  } else {
    // Uncomment the following code block if needed
    // RegExp exp = RegExp(r'Cx(\d|[a-zA-Z])+_(\w+)');
    // Match? match = exp.firstMatch(strValue);
    // if (match != null) {
    //   return int.parse(match.group(1), radix: 16);
    // } else {
    return strValue;
    // }
  }
}
*/
