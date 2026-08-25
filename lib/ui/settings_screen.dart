import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../data/backup_service.dart';
import '../localization/xml_strings.dart';
import '../models/printer_record.dart';
import 'printer_editor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  static final _githubUrl = Uri.parse(
    'https://github.com/pihrt-com/filamentmanager-mobile-app',
  );
  static final _authorUrl = Uri.parse('https://www.pihrt.com');
  static const _releaseDate = '2026-08-25';

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SettingsCard(
              title: strings.appearance,
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(strings.theme),
                  trailing: DropdownButton<ThemeMode>(
                    value: controller.themeMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(strings.themeSystem),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(strings.themeLight),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(strings.themeDark),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) controller.setThemeMode(mode);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(strings.language),
                  trailing: DropdownButton<String>(
                    value: controller.locale?.languageCode ?? 'system',
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text(strings.languageSystem),
                      ),
                      DropdownMenuItem(
                        value: 'cs',
                        child: Text(strings.languageCzech),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(strings.languageEnglish),
                      ),
                    ],
                    onChanged: (language) {
                      controller.setLocale(
                        language == null || language == 'system'
                            ? null
                            : Locale(language),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.managePrinters,
              children: [
                for (final printer in controller.printers)
                  _PrinterSettingsTile(
                    controller: controller,
                    printer: printer,
                  ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(strings.addPrinter),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => PrinterEditorScreen(
                        controller: controller,
                        allowNameEditing: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.dataTransfer,
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: Text(strings.exportDatabase),
                  subtitle: Text(strings.exportDescription),
                  onTap: () => _exportDatabase(context),
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(strings.importDatabase),
                  subtitle: Text(strings.importDescription),
                  onTap: () => _importDatabase(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.nfcTitle,
              children: [
                ListTile(
                  leading: const Icon(Icons.nfc),
                  title: Text(strings.nfcTitle),
                  subtitle: Text(strings.nfcComing),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.about,
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data == null
                        ? '…'
                        : '${snapshot.data!.version} (${snapshot.data!.buildNumber})';
                    return ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(strings.appVersion),
                      subtitle: Text(strings.versionValue(version)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(strings.releaseDate),
                  subtitle: Text(strings.releaseDateValue(_releaseDate)),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(strings.authorName),
                  subtitle: Text(strings.authorWebsite),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_authorUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(strings.sourceCode),
                  subtitle: Text(strings.githubRepository),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_githubUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.phonelink_lock_outlined),
                  title: Text(strings.offlineNote),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  Future<void> _exportDatabase(BuildContext context) async {
    final strings = XmlStrings.of(context);
    final file = await BackupService().createExportFile(controller.printers);
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: strings.exportSubject,
        text: strings.exportMessage,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _importDatabase(BuildContext context) async {
    final strings = XmlStrings.of(context);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: strings.importDatabase,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final source = utf8.decode(await file.readAsBytes());
      final printers = BackupService().decode(source);
      if (!context.mounted) return;
      final mode = await _chooseImportMode(context);
      if (mode == null) return;
      await controller.importPrinters(printers, mode);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.importSuccess)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.importFailed)));
    }
  }

  Future<ImportMode?> _chooseImportMode(BuildContext context) {
    final strings = XmlStrings.of(context);
    return showDialog<ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.importModeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(strings.addExisting),
              subtitle: Text(strings.addExistingDescription),
              onTap: () => Navigator.of(context).pop(ImportMode.add),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(strings.replaceAll),
              subtitle: Text(strings.replaceAllDescription),
              onTap: () => Navigator.of(context).pop(ImportMode.replace),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PrinterSettingsTile extends StatelessWidget {
  const _PrinterSettingsTile({required this.controller, required this.printer});

  final AppController controller;
  final PrinterRecord printer;

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    return ListTile(
      leading: const Icon(Icons.precision_manufacturing),
      title: Text(printer.name),
      subtitle: Text(strings.editPrinter),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PrinterEditorScreen(
            controller: controller,
            printer: printer,
            allowNameEditing: true,
          ),
        ),
      ),
      trailing: IconButton(
        tooltip: strings.deletePrinter,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDelete(context),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final strings = XmlStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteTitle(printer.name)),
        content: Text(strings.deleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deletePrinter(printer);
  }
}
