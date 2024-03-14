import 'package:calibration_reader/views/MyHomePage.dart';
import 'package:flutter/material.dart';

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
