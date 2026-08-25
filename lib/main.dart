import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'data/sqlite_printer_repository.dart';
import 'localization/xml_strings.dart';
import 'theme/app_theme.dart';
import 'ui/root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(repository: SqlitePrinterRepository());
  await controller.initialize();
  runApp(FilamentManagerApp(controller: controller));
}

class FilamentManagerApp extends StatelessWidget {
  const FilamentManagerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => XmlStrings.of(context).appName,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          locale: controller.locale,
          supportedLocales: XmlStrings.supportedLocales,
          localizationsDelegates: const [
            XmlStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RootScreen(controller: controller),
        );
      },
    );
  }
}
