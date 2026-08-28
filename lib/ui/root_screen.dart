import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../sync/filament_sync_service.dart';
import 'home_screen.dart';
import 'printer_editor_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfConnected());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && controller.serverConnected) {
      _syncIfConnected();
    }
  }

  void _syncIfConnected() {
    if (!controller.serverConnected) return;
    controller.synchronize().catchError(
      (_) => SyncResult(
        conflictCount: controller.syncService?.conflictCount ?? 0,
        pendingCount: controller.syncService?.pendingCount ?? 0,
      ),
    );
  }

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
