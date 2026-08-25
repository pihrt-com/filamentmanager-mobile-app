import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/printer_repository.dart';
import 'models/printer_record.dart';

enum ImportMode { replace, add }

class AppController extends ChangeNotifier {
  AppController({required this.repository});

  final PrinterRepository repository;
  List<PrinterRecord> _printers = const [];
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _isReady = false;

  List<PrinterRecord> get printers => List.unmodifiable(_printers);
  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  bool get isReady => _isReady;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == preferences.getString('theme_mode'),
      orElse: () => ThemeMode.system,
    );
    final language = preferences.getString('language');
    _locale = language == null ? null : Locale(language);
    _printers = await repository.loadPrinters();
    _isReady = true;
    notifyListeners();
  }

  Future<void> savePrinter(PrinterRecord printer) async {
    await repository.savePrinter(printer);
    _printers = await repository.loadPrinters();
    notifyListeners();
  }

  Future<void> deletePrinter(PrinterRecord printer) async {
    if (printer.id == null) return;
    await repository.deletePrinter(printer.id!);
    _printers = await repository.loadPrinters();
    notifyListeners();
  }

  Future<void> importPrinters(
    List<PrinterRecord> imported,
    ImportMode mode,
  ) async {
    final normalized = imported
        .map(
          (printer) => PrinterRecord(name: printer.name, slots: printer.slots),
        )
        .toList();
    if (mode == ImportMode.replace) {
      await repository.replacePrinters(normalized);
    } else {
      final usedNames = _printers
          .map((printer) => printer.name.toLowerCase())
          .toSet();
      for (final printer in normalized) {
        var candidate = printer.name;
        var suffix = 2;
        while (usedNames.contains(candidate.toLowerCase())) {
          candidate = '${printer.name} ($suffix)';
          suffix++;
        }
        usedNames.add(candidate.toLowerCase());
        await repository.savePrinter(printer.copyWith(name: candidate));
      }
    }
    _printers = await repository.loadPrinters();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_mode', mode.name);
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    if (locale == null) {
      await preferences.remove('language');
    } else {
      await preferences.setString('language', locale.languageCode);
    }
  }
}
