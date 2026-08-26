import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/printer_repository.dart';
import 'models/printer_record.dart';

enum ImportMode { replace, add }

enum PrinterSortMode { alphabeticalAscending, alphabeticalDescending, custom }

class AppController extends ChangeNotifier {
  AppController({required this.repository});

  final PrinterRepository repository;
  List<PrinterRecord> _printers = const [];
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _isReady = false;
  PrinterSortMode _printerSortMode = PrinterSortMode.alphabeticalAscending;
  List<int> _customPrinterIds = const [];

  List<PrinterRecord> get printers => List.unmodifiable(_printers);
  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  bool get isReady => _isReady;
  PrinterSortMode get printerSortMode => _printerSortMode;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == preferences.getString('theme_mode'),
      orElse: () => ThemeMode.system,
    );
    final language = preferences.getString('language');
    _locale = language == null ? null : Locale(language);
    _printerSortMode = PrinterSortMode.values.firstWhere(
      (mode) => mode.name == preferences.getString('printer_sort_mode'),
      orElse: () => PrinterSortMode.alphabeticalAscending,
    );
    _customPrinterIds =
        preferences
            .getStringList('custom_printer_order')
            ?.map(int.tryParse)
            .whereType<int>()
            .toList() ??
        const [];
    _printers = await repository.loadPrinters();
    _sortPrinters();
    _isReady = true;
    notifyListeners();
  }

  Future<void> savePrinter(PrinterRecord printer) async {
    await repository.savePrinter(printer);
    await _reloadPrinters(persistCustomOrder: true);
    notifyListeners();
  }

  Future<void> deletePrinter(PrinterRecord printer) async {
    if (printer.id == null) return;
    await repository.deletePrinter(printer.id!);
    await _reloadPrinters(persistCustomOrder: true);
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
    await _reloadPrinters(persistCustomOrder: true);
    notifyListeners();
  }

  Future<void> setPrinterSortMode(PrinterSortMode mode) async {
    _printerSortMode = mode;
    if (mode == PrinterSortMode.custom) {
      _customPrinterIds = _printers
          .map((printer) => printer.id)
          .whereType<int>()
          .toList();
    }
    _sortPrinters();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('printer_sort_mode', mode.name);
    if (mode == PrinterSortMode.custom) {
      await _saveCustomOrder(preferences);
    }
  }

  Future<void> reorderPrinters(int oldIndex, int newIndex) async {
    if (_printerSortMode != PrinterSortMode.custom) return;
    final printer = _printers.removeAt(oldIndex);
    _printers.insert(newIndex, printer);
    _customPrinterIds = _printers
        .map((item) => item.id)
        .whereType<int>()
        .toList();
    notifyListeners();
    await _saveCustomOrder(await SharedPreferences.getInstance());
  }

  Future<void> _reloadPrinters({required bool persistCustomOrder}) async {
    _printers = await repository.loadPrinters();
    _sortPrinters();
    if (_printerSortMode == PrinterSortMode.custom && persistCustomOrder) {
      _customPrinterIds = _printers
          .map((item) => item.id)
          .whereType<int>()
          .toList();
      await _saveCustomOrder(await SharedPreferences.getInstance());
    }
  }

  void _sortPrinters() {
    switch (_printerSortMode) {
      case PrinterSortMode.alphabeticalAscending:
        _printers.sort((a, b) => _naturalCompare(a.name, b.name));
      case PrinterSortMode.alphabeticalDescending:
        _printers.sort((a, b) => _naturalCompare(b.name, a.name));
      case PrinterSortMode.custom:
        final ranks = <int, int>{
          for (var index = 0; index < _customPrinterIds.length; index++)
            _customPrinterIds[index]: index,
        };
        _printers.sort((a, b) {
          final aRank = a.id == null ? null : ranks[a.id!];
          final bRank = b.id == null ? null : ranks[b.id!];
          if (aRank != null && bRank != null) return aRank.compareTo(bRank);
          if (aRank != null) return -1;
          if (bRank != null) return 1;
          return _naturalCompare(a.name, b.name);
        });
    }
  }

  Future<void> _saveCustomOrder(SharedPreferences preferences) =>
      preferences.setStringList(
        'custom_printer_order',
        _customPrinterIds.map((id) => id.toString()).toList(),
      );

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

int _naturalCompare(String left, String right) {
  final parts = RegExp(r'\d+|\D+')
      .allMatches(left.toLowerCase())
      .map((match) => match.group(0)!)
      .toList();
  final otherParts = RegExp(r'\d+|\D+')
      .allMatches(right.toLowerCase())
      .map((match) => match.group(0)!)
      .toList();
  final count = parts.length < otherParts.length
      ? parts.length
      : otherParts.length;
  for (var index = 0; index < count; index++) {
    final number = int.tryParse(parts[index]);
    final otherNumber = int.tryParse(otherParts[index]);
    final comparison = number != null && otherNumber != null
        ? number.compareTo(otherNumber)
        : parts[index].compareTo(otherParts[index]);
    if (comparison != 0) return comparison;
  }
  return parts.length.compareTo(otherParts.length);
}
