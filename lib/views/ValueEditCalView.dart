import 'dart:math' as math;
import 'package:calibration_reader/models/CalSelector.dart';
import 'package:calibration_reader/views/Editable.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ValueEditCalView extends StatelessWidget {
  final CalSelector selector;
  final void Function(int row, int col, String value) onValueEdit;

  ValueEditCalView(
      {super.key, required this.selector, required this.onValueEdit});

  @override
  Widget build(BuildContext context) {
    final cal = selector.calibration;
    return LayoutBuilder(
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
                          .mapIndexed((col, c) => editCalValue(-1, col, c,
                              selector, cal.phys.length, constraints.maxWidth))
                          .toList())));
    });
  }

  Widget editCalValue(int row, int col, dynamic calValue, CalSelector selector,
      int length, double maxWidth) {
    final textValue =
        calValue is num ? calValue.toStringAsPrecision(4) : calValue.toString();
    double desWidth = math.min(math.max(70, maxWidth / length), 100);
    return Editable(
        text: textValue,
        width: desWidth,
        onSubmitted: (value) => onValueEdit(row, col, value));
  }
}
