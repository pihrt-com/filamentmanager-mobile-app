import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'home_screen.dart';
import 'printer_editor_screen.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.printers.isEmpty) {
      return PrinterEditorScreen(
        controller: controller,
        isFirstPrinter: true,
        allowNameEditing: true,
      );
    }
    return HomeScreen(controller: controller);
  }
}
