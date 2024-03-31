import 'dart:math' as math;
import 'package:calibration_reader/models/CalSelector.dart';
import 'package:flutter/material.dart';

class NameValueCalView extends StatelessWidget {
  final CalSelector selector;

  NameValueCalView({super.key, required this.selector});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final cal = selector.calibration;
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(cal.name,
            style: appTheme.textTheme.titleMedium!.copyWith(
                color: selector.isSelected ? appTheme.primaryColor : null)),
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
                                  .map((c) => showCalValue(
                                      c, e.length, constraints.maxWidth))
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
                                  maxWidth:
                                      math.max(100, cal.phys.length * 17)),
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
        cal.sst_ref.isNotEmpty ? Text(cal.sst_ref[0]) : const SizedBox.shrink(),
      ]);
    });
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
}
