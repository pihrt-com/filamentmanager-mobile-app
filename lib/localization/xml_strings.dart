import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

class XmlStrings {
  XmlStrings(this.locale, this._values);

  final Locale locale;
  final Map<String, String> _values;

  static const supportedLocales = <Locale>[Locale('en'), Locale('cs')];

  static XmlStrings of(BuildContext context) {
    final value = Localizations.of<XmlStrings>(context, XmlStrings);
    assert(value != null, 'XmlStrings is not available in this context.');
    return value!;
  }

  static Future<XmlStrings> load(Locale locale) async {
    final language = locale.languageCode == 'cs' ? 'cs' : 'en';
    final folder = language == 'cs' ? 'values-cs' : 'values';
    final source = await rootBundle.loadString(
      'assets/i18n/$folder/strings.xml',
    );
    final document = XmlDocument.parse(source);
    final values = <String, String>{};
    for (final element in document.findAllElements('string')) {
      final name = element.getAttribute('name');
      if (name != null) values[name] = element.innerText;
    }
    return XmlStrings(Locale(language), values);
  }

  String _get(String key, [Map<String, Object> arguments = const {}]) {
    var value = _values[key] ?? key;
    for (final entry in arguments.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String get appName => _get('app_name');
  String get printers => _get('printers');
  String get addPrinter => _get('add_printer');
  String get firstPrinterTitle => _get('first_printer_title');
  String get firstPrinterBody => _get('first_printer_body');
  String get printerName => _get('printer_name');
  String get printerNameHint => _get('printer_name_hint');
  String get printerDetails => _get('printer_details');
  String get loadedFilaments => _get('loaded_filaments');
  String get material => _get('material');
  String get materialHint => _get('material_hint');
  String get color => _get('color');
  String get colorHint => _get('color_hint');
  String get remainingWeight => _get('remaining_weight');
  String get grams => _get('grams');
  String weightValue(Object grams) => _get('weight_value', {'grams': grams});
  String get addFilament => _get('add_filament');
  String get removeFilament => _get('remove_filament');
  String get save => _get('save');
  String get cancel => _get('cancel');
  String get settings => _get('settings');
  String get appearance => _get('appearance');
  String get theme => _get('theme');
  String get themeSystem => _get('theme_system');
  String get themeLight => _get('theme_light');
  String get themeDark => _get('theme_dark');
  String get language => _get('language');
  String get languageSystem => _get('language_system');
  String get languageEnglish => _get('language_english');
  String get languageCzech => _get('language_czech');
  String get managePrinters => _get('manage_printers');
  String get printerSorting => _get('printer_sorting');
  String get sortAlphabeticalAscending => _get('sort_alphabetical_ascending');
  String get sortAlphabeticalDescending => _get('sort_alphabetical_descending');
  String get sortCustom => _get('sort_custom');
  String get customSortHelp => _get('custom_sort_help');
  String get dataTransfer => _get('data_transfer');
  String get exportDatabase => _get('export_database');
  String get exportDescription => _get('export_description');
  String get importDatabase => _get('import_database');
  String get importDescription => _get('import_description');
  String get importModeTitle => _get('import_mode_title');
  String get replaceAll => _get('replace_all');
  String get replaceAllDescription => _get('replace_all_description');
  String get addExisting => _get('add_existing');
  String get addExistingDescription => _get('add_existing_description');
  String get importSuccess => _get('import_success');
  String get importFailed => _get('import_failed');
  String get exportSubject => _get('export_subject');
  String get exportMessage => _get('export_message');
  String get editPrinter => _get('edit_printer');
  String get editFilaments => _get('edit_filaments');
  String get deletePrinter => _get('delete_printer');
  String deleteTitle(String printer) =>
      _get('delete_title', {'printer': printer});
  String get deleteMessage => _get('delete_message');
  String get delete => _get('delete');
  String get noPrinters => _get('no_printers');
  String get noFilaments => _get('no_filaments');
  String get requiredField => _get('required_field');
  String get duplicatePrinter => _get('duplicate_printer');
  String get invalidWeight => _get('invalid_weight');
  String get nfcTitle => _get('nfc_title');
  String get nfcWebsite => _get('nfc_website');
  String get nfcRead => _get('nfc_read');
  String get nfcWrite => _get('nfc_write');
  String get nfcWriteWeight => _get('nfc_write_weight');
  String get nfcHoldNear => _get('nfc_hold_near');
  String get nfcScanReadMessage => _get('nfc_scan_read_message');
  String get nfcScanWriteMessage => _get('nfc_scan_write_message');
  String get nfcReadSuccess => _get('nfc_read_success');
  String get nfcWriteSuccess => _get('nfc_write_success');
  String get nfcReadFirst => _get('nfc_read_first');
  String get nfcWriteTitle => _get('nfc_write_title');
  String nfcWriteConfirm(String grams) =>
      _get('nfc_write_confirm', {'grams': grams});
  String nfcLinkedTag(String uid) => _get('nfc_linked_tag', {'uid': uid});
  String nfcBrand(String brand) => _get('nfc_brand', {'brand': brand});
  String get nfcNotLinked => _get('nfc_not_linked');
  String get nfcUnsupported => _get('nfc_unsupported');
  String get nfcDisabled => _get('nfc_disabled');
  String get nfcTimeout => _get('nfc_timeout');
  String get nfcNotNfcV => _get('nfc_not_nfcv');
  String get nfcNotOpenPrintTag => _get('nfc_not_openprinttag');
  String get nfcCorrupt => _get('nfc_corrupt');
  String get nfcNotWritable => _get('nfc_not_writable');
  String get nfcAuxFull => _get('nfc_aux_full');
  String get nfcDifferentTag => _get('nfc_different_tag');
  String get nfcWriteFailed => _get('nfc_write_failed');
  String get nfcInvalidTag => _get('nfc_invalid_tag');
  String get about => _get('about');
  String get appVersion => _get('app_version');
  String versionValue(String version) =>
      _get('version_value', {'version': version});
  String get releaseDate => _get('release_date');
  String releaseDateValue(String date) =>
      _get('release_date_value', {'date': date});
  String get author => _get('author');
  String get authorName => _get('author_name');
  String get authorWebsite => _get('author_website');
  String get sourceCode => _get('source_code');
  String get githubRepository => _get('github_repository');
  String get offlineNote => _get('offline_note');
  String positionNumber(int number) =>
      _get('position_number', {'number': number});
  String get unsavedChanges => _get('unsaved_changes');
  String get discard => _get('discard');
  String get keepEditing => _get('keep_editing');
  String get emptySlotHelp => _get('empty_slot_help');
  String get black => _get('black');
  String get white => _get('white');
  String get gray => _get('gray');
  String get red => _get('red');
  String get orange => _get('orange');
  String get yellow => _get('yellow');
  String get green => _get('green');
  String get blue => _get('blue');
  String get purple => _get('purple');
  String get brown => _get('brown');
  String get chooseColor => _get('choose_color');
  String get customColor => _get('custom_color');
  String get hexColor => _get('hex_color');
  String get invalidHexColor => _get('invalid_hex_color');
  String get moreInformation => _get('more_information');
  String get spoolDetails => _get('spool_details');
  String get manufacturer => _get('manufacturer');
  String get commercialName => _get('commercial_name');
  String get diameterMm => _get('diameter_mm');
  String get originalWeight => _get('original_weight');
  String get tareWeight => _get('tare_weight');
  String get purchaseDate => _get('purchase_date');
  String get dateHint => _get('date_hint');
  String get storageLocation => _get('storage_location');
  String get storageLocationCode => _get('storage_location_code');
  String get batchNumber => _get('batch_number');
  String get openPrintTagId => _get('openprinttag_id');
  String get notes => _get('notes');
  String get serverSection => _get('server_section');
  String get serverEnable => _get('server_enable');
  String get serverEnableDescription => _get('server_enable_description');
  String get serverUrl => _get('server_url');
  String get serverUrlHint => _get('server_url_hint');
  String get serverUsername => _get('server_username');
  String get serverPassword => _get('server_password');
  String get serverConnect => _get('server_connect');
  String serverConnected(String user, String role) =>
      _get('server_connected', {'user': user, 'role': role});
  String serverVersion(String version) =>
      _get('server_version', {'version': version});
  String serverLastSync(String date) =>
      _get('server_last_sync', {'date': date});
  String get serverNeverSynced => _get('server_never_synced');
  String serverPending(int count) => _get('server_pending', {'count': count});
  String serverConflicts(int count) =>
      _get('server_conflicts', {'count': count});
  String get syncNow => _get('sync_now');
  String get syncSuccess => _get('sync_success');
  String syncFailed(Object message) =>
      _get('sync_failed', {'message': message});
  String get serverLoginRejected => _get('server_login_rejected');
  String get serverSessionExpired => _get('server_session_expired');
  String get serverPermissionDenied => _get('server_permission_denied');
  String get serverNotFound => _get('server_not_found');
  String get serverUnavailable => _get('server_unavailable');
  String get serverTimeout => _get('server_timeout');
  String get serverInvalidResponse => _get('server_invalid_response');
  String get serverInvalidAddress => _get('server_invalid_address');
  String get serverRequestRejected => _get('server_request_rejected');
  String get serverConnectionFailed => _get('server_connection_failed');
  String get serverDisconnect => _get('server_disconnect');
  String get serverGithub => _get('server_github');
  String get serverGithubRepository => _get('server_github_repository');
  String get initialSyncTitle => _get('initial_sync_title');
  String initialSyncSummary(int local, int server) =>
      _get('initial_sync_summary', {'local': local, 'server': server});
  String get initialUpload => _get('initial_upload');
  String get initialUploadDescription => _get('initial_upload_description');
  String get initialDownload => _get('initial_download');
  String get initialDownloadDescription => _get('initial_download_description');
  String get initialMerge => _get('initial_merge');
  String get initialMergeDescription => _get('initial_merge_description');
  String initialConflicts(String names) =>
      _get('initial_conflicts', {'names': names});
  String get resolveConflictsTitle => _get('resolve_conflicts_title');
  String resolveConflictsMessage(int count) =>
      _get('resolve_conflicts_message', {'count': count});
  String get keepServer => _get('keep_server');
  String get keepPhone => _get('keep_phone');
  String get offlineServerNote => _get('offline_server_note');
  String get serverReadOnly => _get('server_read_only');
}

class XmlStringsDelegate extends LocalizationsDelegate<XmlStrings> {
  const XmlStringsDelegate();

  @override
  bool isSupported(Locale locale) => XmlStrings.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<XmlStrings> load(Locale locale) =>
      SynchronousFuture(null).then((_) => XmlStrings.load(locale));

  @override
  bool shouldReload(XmlStringsDelegate old) => false;
}
