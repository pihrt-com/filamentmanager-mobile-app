import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../data/backup_service.dart';
import '../localization/xml_strings.dart';
import '../models/printer_record.dart';
import '../sync/filament_server_api.dart';
import '../sync/filament_sync_service.dart';
import 'printer_editor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  static final _githubUrl = Uri.parse(
    'https://github.com/pihrt-com/filamentmanager-mobile-app',
  );
  static final _serverGithubUrl = Uri.parse(
    'https://github.com/pihrt-com/filamentmanager-server',
  );
  static final _authorUrl = Uri.parse('https://www.pihrt.com');
  static final _openPrintTagUrl = Uri.parse('https://openprinttag.org/');
  static const _releaseDate = '2026-08-28';

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
            if (controller.syncService != null) ...[
              ListenableBuilder(
                listenable: controller,
                builder: (context, child) =>
                    _ServerSettingsCard(controller: controller),
              ),
              const SizedBox(height: 16),
            ],
            ListenableBuilder(
              listenable: controller,
              builder: (context, child) =>
                  _buildPrinterManagement(context, strings),
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
                  subtitle: Text(strings.nfcWebsite),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_openPrintTagUrl),
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
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(strings.serverGithub),
                  subtitle: Text(strings.serverGithubRepository),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_serverGithubUrl),
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

  Widget _buildPrinterManagement(BuildContext context, XmlStrings strings) {
    final custom = controller.printerSortMode == PrinterSortMode.custom;
    return _SettingsCard(
      title: strings.managePrinters,
      children: [
        ListTile(
          leading: const Icon(Icons.sort_by_alpha),
          title: Text(strings.printerSorting),
          trailing: DropdownButton<PrinterSortMode>(
            value: controller.printerSortMode,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: PrinterSortMode.alphabeticalAscending,
                child: Text(strings.sortAlphabeticalAscending),
              ),
              DropdownMenuItem(
                value: PrinterSortMode.alphabeticalDescending,
                child: Text(strings.sortAlphabeticalDescending),
              ),
              DropdownMenuItem(
                value: PrinterSortMode.custom,
                child: Text(strings.sortCustom),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) controller.setPrinterSortMode(mode);
            },
          ),
        ),
        if (custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              strings.customSortHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (custom)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: controller.printers.length,
            onReorderItem: controller.reorderPrinters,
            itemBuilder: (context, index) {
              final printer = controller.printers[index];
              return _PrinterSettingsTile(
                key: ValueKey(printer.id ?? printer.name),
                controller: controller,
                printer: printer,
                reorderIndex: index,
              );
            },
          )
        else
          for (final printer in controller.printers)
            _PrinterSettingsTile(
              key: ValueKey(printer.id ?? printer.name),
              controller: controller,
              printer: printer,
            ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text(strings.addPrinter),
          enabled: controller.canEdit,
          onTap: controller.canEdit
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => PrinterEditorScreen(
                      controller: controller,
                      allowNameEditing: true,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

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

class _ServerSettingsCard extends StatefulWidget {
  const _ServerSettingsCard({required this.controller});

  final AppController controller;

  @override
  State<_ServerSettingsCard> createState() => _ServerSettingsCardState();
}

class _ServerSettingsCardState extends State<_ServerSettingsCard> {
  late final TextEditingController _url;
  late final TextEditingController _username;
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  FilamentSyncService get _sync => widget.controller.syncService!;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: _sync.serverUrl);
    _username = TextEditingController(text: _sync.username);
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    return _SettingsCard(
      title: strings.serverSection,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: Text(strings.serverEnable),
          subtitle: Text(strings.serverEnableDescription),
          value: _sync.enabled,
          onChanged: _busy
              ? null
              : (value) async {
                  await widget.controller.setServerEnabled(value);
                  if (mounted) setState(() {});
                },
        ),
        if (_sync.enabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enabled: !_sync.connected && !_busy,
              decoration: InputDecoration(
                labelText: strings.serverUrl,
                hintText: strings.serverUrlHint,
                prefixIcon: const Icon(Icons.link),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _username,
              autocorrect: false,
              enabled: !_sync.connected && !_busy,
              decoration: InputDecoration(
                labelText: strings.serverUsername,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
          ),
          if (!_sync.connected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _password,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: strings.serverPassword,
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) => _connect(),
              ),
            ),
          if (!_sync.connected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(strings.serverConnect),
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: Text(
                strings.serverConnected(
                  _sync.displayName ?? _sync.username,
                  _sync.role ?? '—',
                ),
              ),
              subtitle: Text(
                _sync.serverVersion == null
                    ? _sync.serverUrl
                    : '${_sync.serverUrl}\n${strings.serverVersion(_sync.serverVersion!)}',
              ),
              isThreeLine: _sync.serverVersion != null,
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                _sync.lastSyncAt == null
                    ? strings.serverNeverSynced
                    : strings.serverLastSync(
                        _sync.lastSyncAt!.toLocal().toString(),
                      ),
              ),
              subtitle: Text(
                '${strings.serverPending(_sync.pendingCount)}\n'
                '${strings.serverConflicts(_sync.conflictCount)}',
              ),
              isThreeLine: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _synchronize,
                    icon: const Icon(Icons.sync),
                    label: Text(strings.syncNow),
                  ),
                  if (_sync.conflictCount > 0)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _resolveConflicts,
                      icon: const Icon(Icons.rule),
                      label: Text(strings.resolveConflictsTitle),
                    ),
                  TextButton.icon(
                    onPressed: _busy ? null : _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text(strings.serverDisconnect),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              strings.offlineServerNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _connect() async {
    final strings = XmlStrings.of(context);
    if (_url.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _password.text.isEmpty) {
      _message(strings.requiredField);
      return;
    }
    setState(() => _busy = true);
    try {
      final package = await PackageInfo.fromPlatform();
      final preview = await widget.controller.connectServer(
        url: _url.text,
        username: _username.text,
        password: _password.text,
        appVersion: package.version,
      );
      _password.clear();
      if (!mounted) return;
      final mode = await _chooseInitialMode(preview);
      if (mode == null) return;
      final result = await widget.controller.completeInitialSync(preview, mode);
      if (!mounted) return;
      if (result.conflictCount > 0) {
        await _resolveConflicts();
      } else {
        _message(strings.syncSuccess);
      }
    } on Object catch (error) {
      if (mounted) _message(_serverError(strings, error, signingIn: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<InitialSyncMode?> _chooseInitialMode(InitialSyncPreview preview) {
    final strings = XmlStrings.of(context);
    return showDialog<InitialSyncMode>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(strings.initialSyncTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.initialSyncSummary(
                  preview.localPrinterCount,
                  preview.serverPrinterCount,
                ),
              ),
              if (preview.conflictingPrinterNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  strings.initialConflicts(
                    preview.conflictingPrinterNames.join(', '),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.upload),
                title: Text(strings.initialUpload),
                subtitle: Text(strings.initialUploadDescription),
                enabled: preview.serverPrinterCount == 0 && _sync.canWrite,
                onTap: preview.serverPrinterCount == 0 && _sync.canWrite
                    ? () => Navigator.pop(context, InitialSyncMode.upload)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(strings.initialDownload),
                subtitle: Text(strings.initialDownloadDescription),
                onTap: () => Navigator.pop(context, InitialSyncMode.download),
              ),
              ListTile(
                leading: const Icon(Icons.merge),
                title: Text(strings.initialMerge),
                subtitle: Text(strings.initialMergeDescription),
                enabled: _sync.canWrite,
                onTap: _sync.canWrite
                    ? () => Navigator.pop(context, InitialSyncMode.merge)
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _synchronize() async {
    final strings = XmlStrings.of(context);
    setState(() => _busy = true);
    try {
      final result = await widget.controller.synchronize();
      if (!mounted) return;
      if (result.conflictCount > 0) {
        await _resolveConflicts();
      } else {
        _message(strings.syncSuccess);
      }
    } on Object catch (error) {
      if (mounted) _message(_serverError(strings, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveConflicts() async {
    final strings = XmlStrings.of(context);
    final keepPhone = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.resolveConflictsTitle),
        content: Text(strings.resolveConflictsMessage(_sync.conflictCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.keepServer),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.keepPhone),
          ),
        ],
      ),
    );
    if (keepPhone == null) return;
    await widget.controller.resolveSyncConflicts(keepPhone: keepPhone);
    if (mounted) _message(strings.syncSuccess);
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    await widget.controller.disconnectServer();
    if (mounted) setState(() => _busy = false);
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  String _serverError(
    XmlStrings strings,
    Object error, {
    bool signingIn = false,
  }) {
    if (error is FilamentServerException) {
      if (error.kind == FilamentServerErrorKind.invalidAddress) {
        return strings.serverInvalidAddress;
      }
      if (error.kind == FilamentServerErrorKind.authenticationRequired) {
        return strings.serverSessionExpired;
      }
      if (error.kind == FilamentServerErrorKind.invalidResponse) {
        return strings.serverInvalidResponse;
      }
      final status = error.statusCode;
      if (status == 401) {
        return signingIn
            ? strings.serverLoginRejected
            : strings.serverSessionExpired;
      }
      if (status == 403) return strings.serverPermissionDenied;
      if (status == 404) return strings.serverNotFound;
      if (status != null && status >= 500) return strings.serverUnavailable;
      return status == null
          ? strings.serverConnectionFailed
          : strings.serverRequestRejected;
    }
    if (error is TimeoutException) return strings.serverTimeout;
    if (error is SocketException) return strings.serverUnavailable;
    if (error is FormatException) return strings.serverInvalidResponse;
    return strings.serverConnectionFailed;
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
  const _PrinterSettingsTile({
    super.key,
    required this.controller,
    required this.printer,
    this.reorderIndex,
  });

  final AppController controller;
  final PrinterRecord printer;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    return ListTile(
      leading: const Icon(Icons.precision_manufacturing),
      title: Text(printer.name),
      subtitle: Text(strings.editPrinter),
      enabled: controller.canEdit,
      onTap: controller.canEdit
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => PrinterEditorScreen(
                  controller: controller,
                  printer: printer,
                  allowNameEditing: true,
                ),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: strings.deletePrinter,
            icon: const Icon(Icons.delete_outline),
            onPressed: controller.canEdit
                ? () => _confirmDelete(context)
                : null,
          ),
          if (reorderIndex != null)
            ReorderableDragStartListener(
              index: reorderIndex!,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle),
              ),
            ),
        ],
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
