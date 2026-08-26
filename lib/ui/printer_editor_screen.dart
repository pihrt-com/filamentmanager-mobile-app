import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../localization/xml_strings.dart';
import '../models/filament_materials.dart';
import '../models/filament_slot.dart';
import '../models/printer_record.dart';
import '../nfc/open_print_tag.dart';
import '../nfc/open_print_tag_nfc_service.dart';

class PrinterEditorScreen extends StatefulWidget {
  const PrinterEditorScreen({
    super.key,
    required this.controller,
    this.printer,
    this.isFirstPrinter = false,
    this.allowNameEditing = false,
  });

  final AppController controller;
  final PrinterRecord? printer;
  final bool isFirstPrinter;
  final bool allowNameEditing;

  @override
  State<PrinterEditorScreen> createState() => _PrinterEditorScreenState();
}

class _PrinterEditorScreenState extends State<PrinterEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final List<_SlotDraft> _slots;
  bool _saving = false;
  int? _nfcBusySlot;
  final _nfcService = OpenPrintTagNfcService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.printer?.name ?? '');
    _slots =
        widget.printer?.slots.map(_SlotDraft.fromSlot).toList() ??
        [_SlotDraft.empty()];
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  void _addSlot() => setState(() => _slots.add(_SlotDraft.empty()));

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    final strings = XmlStrings.of(context);
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final duplicate = widget.controller.printers.any(
      (printer) =>
          printer.id != widget.printer?.id &&
          printer.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.duplicatePrinter)));
      return;
    }
    setState(() => _saving = true);
    final slots = <FilamentSlot>[];
    for (var index = 0; index < _slots.length; index++) {
      final draft = _slots[index];
      slots.add(
        FilamentSlot(
          position: index + 1,
          material: draft.material.text.trim(),
          colorName: draft.colorName.text.trim(),
          colorValue: draft.color.toARGB32(),
          remainingGrams: double.parse(draft.weight.text.replaceAll(',', '.')),
          tagUid: draft.tagUid,
          tagInstanceId: draft.tagInstanceId,
          tagBrand: draft.tagBrand,
          tagFullWeightGrams: draft.tagFullWeightGrams,
          tagLastReadAt: draft.tagLastReadAt,
        ),
      );
    }
    await widget.controller.savePrinter(
      PrinterRecord(id: widget.printer?.id, name: name, slots: slots),
    );
    if (mounted && !widget.isFirstPrinter) Navigator.of(context).pop();
  }

  Future<void> _readTag(int index) async {
    final strings = XmlStrings.of(context);
    setState(() => _nfcBusySlot = index);
    _showScanningDialog(strings.nfcScanReadMessage);
    try {
      final tag = await _nfcService.read();
      if (!mounted) return;
      final draft = _slots[index];
      setState(() {
        if (tag.material.isNotEmpty) draft.material.text = tag.material;
        if (tag.colorValue != null) {
          draft.color = Color(tag.colorValue!);
          draft.colorName.text = _hexColorName(tag.colorValue!);
        }
        if (tag.remainingWeightGrams != null) {
          draft.weight.text = _formatWeight(tag.remainingWeightGrams!);
        }
        draft
          ..tagUid = tag.uid
          ..tagInstanceId = tag.instanceId
          ..tagBrand = tag.brand
          ..tagFullWeightGrams = tag.fullWeightGrams
          ..tagLastReadAt = DateTime.now().toUtc();
      });
      _message(strings.nfcReadSuccess);
    } on OpenPrintTagException catch (error) {
      if (mounted) _message(_nfcError(strings, error.error));
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _nfcBusySlot = null);
      }
    }
  }

  Future<void> _writeTag(int index) async {
    final strings = XmlStrings.of(context);
    final draft = _slots[index];
    final remaining = double.tryParse(draft.weight.text.replaceAll(',', '.'));
    if (remaining == null || draft.tagUid == null) {
      _message(strings.nfcReadFirst);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.nfcWriteTitle),
        content: Text(strings.nfcWriteConfirm(_formatWeight(remaining))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.nfcWrite),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _nfcBusySlot = index);
    _showScanningDialog(strings.nfcScanWriteMessage);
    try {
      final tag = await _nfcService.writeRemainingWeight(
        expectedUid: draft.tagUid!,
        expectedInstanceId: draft.tagInstanceId,
        remainingGrams: remaining,
      );
      if (!mounted) return;
      setState(() {
        draft
          ..tagLastReadAt = DateTime.now().toUtc()
          ..tagFullWeightGrams = tag.fullWeightGrams;
      });
      _message(strings.nfcWriteSuccess);
    } on OpenPrintTagException catch (error) {
      if (mounted) _message(_nfcError(strings, error.error));
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _nfcBusySlot = null);
      }
    }
  }

  void _showScanningDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.nfc, size: 42),
          title: Text(XmlStrings.of(context).nfcHoldNear),
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  String _nfcError(XmlStrings strings, OpenPrintTagError error) =>
      switch (error) {
        OpenPrintTagError.nfcUnsupported => strings.nfcUnsupported,
        OpenPrintTagError.nfcDisabled => strings.nfcDisabled,
        OpenPrintTagError.scanTimeout => strings.nfcTimeout,
        OpenPrintTagError.notNfcV => strings.nfcNotNfcV,
        OpenPrintTagError.notOpenPrintTag => strings.nfcNotOpenPrintTag,
        OpenPrintTagError.corruptData => strings.nfcCorrupt,
        OpenPrintTagError.noAuxRegion ||
        OpenPrintTagError.notWritable => strings.nfcNotWritable,
        OpenPrintTagError.invalidWeight => strings.invalidWeight,
        OpenPrintTagError.auxRegionFull => strings.nfcAuxFull,
        OpenPrintTagError.differentTag => strings.nfcDifferentTag,
        OpenPrintTagError.writeFailed => strings.nfcWriteFailed,
        OpenPrintTagError.invalidTag => strings.nfcInvalidTag,
      };

  String _formatWeight(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  String _hexColorName(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    final title = widget.isFirstPrinter
        ? strings.firstPrinterTitle
        : widget.printer == null
        ? strings.addPrinter
        : strings.editFilaments;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isFirstPrinter,
        title: Text(title),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 780;
              final maxWidth = horizontal ? 1000.0 : 680.0;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.isFirstPrinter) ...[
                            Text(
                              strings.firstPrinterBody,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 20),
                          ],
                          _SectionCard(
                            title: strings.printerDetails,
                            child: TextFormField(
                              controller: _nameController,
                              enabled: widget.allowNameEditing,
                              autofocus: widget.printer == null,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: strings.printerName,
                                hintText: strings.printerNameHint,
                                prefixIcon: const Icon(
                                  Icons.precision_manufacturing,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? strings.requiredField
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: strings.loadedFilaments,
                            child: Column(
                              children: [
                                if (_slots.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(strings.emptySlotHelp),
                                  ),
                                for (
                                  var index = 0;
                                  index < _slots.length;
                                  index++
                                ) ...[
                                  _SlotEditor(
                                    key: ValueKey(_slots[index]),
                                    draft: _slots[index],
                                    number: index + 1,
                                    onRemove: () => _removeSlot(index),
                                    onReadTag: () => _readTag(index),
                                    onWriteTag: () => _writeTag(index),
                                    nfcBusy: _nfcBusySlot != null,
                                  ),
                                  if (index != _slots.length - 1)
                                    const Divider(height: 32),
                                ],
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _addSlot,
                                  icon: const Icon(Icons.add),
                                  label: Text(strings.addFilament),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(strings.save),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SlotEditor extends StatefulWidget {
  const _SlotEditor({
    super.key,
    required this.draft,
    required this.number,
    required this.onRemove,
    required this.onReadTag,
    required this.onWriteTag,
    required this.nfcBusy,
  });

  final _SlotDraft draft;
  final int number;
  final VoidCallback onRemove;
  final VoidCallback onReadTag;
  final VoidCallback onWriteTag;
  final bool nfcBusy;

  @override
  State<_SlotEditor> createState() => _SlotEditorState();
}

class _SlotEditorState extends State<_SlotEditor> {
  static final _openPrintTagUrl = Uri.parse('https://openprinttag.org/');
  static const palette = <Color>[
    Color(0xFF171717),
    Color(0xFFFFFFFF),
    Color(0xFF808080),
    Color(0xFFE53935),
    Color(0xFFFF7A00),
    Color(0xFFFFD600),
    Color(0xFF2EAD5B),
    Color(0xFF2878D0),
    Color(0xFF8B52C7),
    Color(0xFF795548),
  ];

  List<String> _colorNames(XmlStrings strings) => [
    strings.black,
    strings.white,
    strings.gray,
    strings.red,
    strings.orange,
    strings.yellow,
    strings.green,
    strings.blue,
    strings.purple,
    strings.brown,
  ];

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.positionNumber(widget.number),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: strings.removeFilament,
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: widget.draft.material.text),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            final matches = filamentMaterials.where(
              (material) => material.toLowerCase().contains(query),
            );
            return [
              ...matches.where(
                (material) => material.toLowerCase().startsWith(query),
              ),
              ...matches.where(
                (material) => !material.toLowerCase().startsWith(query),
              ),
            ];
          },
          onSelected: (value) => widget.draft.material.text = value,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: strings.material,
                hintText: strings.materialHint,
              ),
              onChanged: (value) => widget.draft.material.text = value,
              onFieldSubmitted: (_) => onFieldSubmitted(),
              validator: (value) => value == null || value.trim().isEmpty
                  ? strings.requiredField
                  : null,
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.draft.colorName,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: strings.color,
            hintText: strings.colorHint,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(13),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.draft.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? strings.requiredField
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          strings.chooseColor,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < palette.length; index++)
              Semantics(
                label: _colorNames(strings)[index],
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    widget.draft.color = palette[index];
                    widget.draft.colorName.text = _colorNames(strings)[index];
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: widget.draft.color == palette[index] ? 3 : 1,
                        color: widget.draft.color == palette[index]
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.draft.weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
          decoration: InputDecoration(
            labelText: strings.remainingWeight,
            suffixText: strings.grams,
          ),
          validator: (value) {
            final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
            return parsed == null || parsed < 0 ? strings.invalidWeight : null;
          },
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.nfc),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.nfcTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      _openPrintTagUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(strings.nfcWebsite),
                  ),
                ),
                if (widget.draft.tagUid != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    strings.nfcLinkedTag(widget.draft.tagUid!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (widget.draft.tagBrand?.isNotEmpty == true)
                    Text(
                      strings.nfcBrand(widget.draft.tagBrand!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    strings.nfcNotLinked,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.nfcBusy ? null : widget.onReadTag,
                      icon: const Icon(Icons.download),
                      label: Text(strings.nfcRead),
                    ),
                    if (widget.draft.tagUid != null)
                      FilledButton.tonalIcon(
                        onPressed: widget.nfcBusy ? null : widget.onWriteTag,
                        icon: const Icon(Icons.upload),
                        label: Text(strings.nfcWriteWeight),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlotDraft {
  _SlotDraft({
    required this.material,
    required this.colorName,
    required this.weight,
    required this.color,
    this.tagUid,
    this.tagInstanceId,
    this.tagBrand,
    this.tagFullWeightGrams,
    this.tagLastReadAt,
  });

  factory _SlotDraft.empty() => _SlotDraft(
    material: TextEditingController(),
    colorName: TextEditingController(),
    weight: TextEditingController(text: '1000'),
    color: const Color(0xFF171717),
  );

  factory _SlotDraft.fromSlot(FilamentSlot slot) => _SlotDraft(
    material: TextEditingController(text: slot.material),
    colorName: TextEditingController(text: slot.colorName),
    weight: TextEditingController(
      text: slot.remainingGrams == slot.remainingGrams.roundToDouble()
          ? slot.remainingGrams.toInt().toString()
          : slot.remainingGrams.toString(),
    ),
    color: Color(slot.colorValue),
    tagUid: slot.tagUid,
    tagInstanceId: slot.tagInstanceId,
    tagBrand: slot.tagBrand,
    tagFullWeightGrams: slot.tagFullWeightGrams,
    tagLastReadAt: slot.tagLastReadAt,
  );

  final TextEditingController material;
  final TextEditingController colorName;
  final TextEditingController weight;
  Color color;
  String? tagUid;
  String? tagInstanceId;
  String? tagBrand;
  double? tagFullWeightGrams;
  DateTime? tagLastReadAt;

  void dispose() {
    material.dispose();
    colorName.dispose();
    weight.dispose();
  }
}
