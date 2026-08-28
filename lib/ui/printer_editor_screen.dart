import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          id: draft.id,
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
          manufacturer: draft.manufacturer.text.trim().nullIfEmpty,
          commercialName: draft.commercialName.text.trim().nullIfEmpty,
          diameterMm:
              double.tryParse(draft.diameter.text.replaceAll(',', '.')) ?? 1.75,
          originalWeightGrams: double.tryParse(
            draft.originalWeight.text.replaceAll(',', '.'),
          ),
          tareWeightGrams: double.tryParse(
            draft.tareWeight.text.replaceAll(',', '.'),
          ),
          purchaseDate: DateTime.tryParse(draft.purchaseDate.text.trim()),
          storageLocation: draft.storageLocation.text.trim().nullIfEmpty,
          storageLocationCode: draft.storageLocationCode.text
              .trim()
              .nullIfEmpty,
          batchNumber: draft.batchNumber.text.trim().nullIfEmpty,
          openPrintTagId: draft.openPrintTagId.text.trim().nullIfEmpty,
          notes: draft.notes.text.trim().nullIfEmpty,
          serverSlotId: draft.serverSlotId,
          serverSlotVersion: draft.serverSlotVersion,
          serverMaterialId: draft.serverMaterialId,
          serverMaterialVersion: draft.serverMaterialVersion,
          serverSpoolId: draft.serverSpoolId,
          serverSpoolVersion: draft.serverSpoolVersion,
          serverManufacturerId: draft.serverManufacturerId,
          serverManufacturerVersion: draft.serverManufacturerVersion,
          serverLocationId: draft.serverLocationId,
          serverLocationVersion: draft.serverLocationVersion,
        ),
      );
    }
    await widget.controller.savePrinter(
      PrinterRecord(
        id: widget.printer?.id,
        name: name,
        slots: slots,
        manufacturer: widget.printer?.manufacturer,
        model: widget.printer?.model,
        description: widget.printer?.description,
        status: widget.printer?.status ?? 'active',
        serverId: widget.printer?.serverId,
        serverVersion: widget.printer?.serverVersion ?? 0,
      ),
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
            OutlinedButton.icon(
              onPressed: _chooseCustomColor,
              icon: const Icon(Icons.colorize),
              label: Text(strings.customColor),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.nfcBusy ? null : widget.onReadTag,
              icon: const Icon(Icons.nfc),
              label: Text(strings.nfcRead),
            ),
            if (widget.draft.tagUid != null)
              FilledButton.tonalIcon(
                onPressed: widget.nfcBusy ? null : widget.onWriteTag,
                icon: const Icon(Icons.upload),
                label: Text(strings.nfcWriteWeight),
              ),
            OutlinedButton.icon(
              onPressed: _showDetails,
              icon: const Icon(Icons.info_outline),
              label: Text(strings.moreInformation),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _chooseCustomColor() async {
    final strings = XmlStrings.of(context);
    var red = widget.draft.color.r;
    var green = widget.draft.color.g;
    var blue = widget.draft.color.b;
    var invalidHex = false;
    final hexController = TextEditingController(
      text:
          '#${(widget.draft.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    );
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final color = Color.from(
            alpha: 1,
            red: red,
            green: green,
            blue: blue,
          );
          final hex =
              '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
          void updateChannel(VoidCallback update) {
            setDialogState(() {
              update();
              invalidHex = false;
              final value = Color.from(
                alpha: 1,
                red: red,
                green: green,
                blue: blue,
              );
              hexController.text =
                  '#${(value.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
            });
          }

          Widget slider(
            String label,
            double value,
            ValueChanged<double> onChanged,
          ) {
            return Row(
              children: [
                SizedBox(width: 24, child: Text(label)),
                Expanded(
                  child: Slider(
                    value: value * 255,
                    max: 255,
                    divisions: 255,
                    label: (value * 255).round().toString(),
                    onChanged: (next) => onChanged(next / 255),
                  ),
                ),
                SizedBox(width: 36, child: Text('${(value * 255).round()}')),
              ],
            );
          }

          return AlertDialog(
            title: Text(strings.customColor),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hexController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: strings.hexColor,
                    hintText: '#RRGGBB',
                    errorText: invalidHex ? strings.invalidHexColor : null,
                  ),
                  onSubmitted: (value) {
                    final match = RegExp(r'^#?([0-9A-Fa-f]{6})$')
                        .firstMatch(value.trim());
                    if (match == null) {
                      setDialogState(() => invalidHex = true);
                      return;
                    }
                    final rgb = int.parse(match.group(1)!, radix: 16);
                    setDialogState(() {
                      red = ((rgb >> 16) & 0xFF) / 255;
                      green = ((rgb >> 8) & 0xFF) / 255;
                      blue = (rgb & 0xFF) / 255;
                      invalidHex = false;
                      hexController.text = '#${match.group(1)!.toUpperCase()}';
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(hex, style: Theme.of(context).textTheme.titleSmall),
                slider('R', red, (value) => updateChannel(() => red = value)),
                slider(
                  'G',
                  green,
                  (value) => updateChannel(() => green = value),
                ),
                slider('B', blue, (value) => updateChannel(() => blue = value)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final match = RegExp(r'^#?([0-9A-Fa-f]{6})$')
                      .firstMatch(hexController.text.trim());
                  if (match == null) {
                    setDialogState(() => invalidHex = true);
                    return;
                  }
                  Navigator.pop(
                    context,
                    Color(0xFF000000 | int.parse(match.group(1)!, radix: 16)),
                  );
                },
                child: Text(strings.save),
              ),
            ],
          );
        },
      ),
    );
    hexController.dispose();
    if (result != null) {
      setState(() {
        widget.draft.color = result;
        widget.draft.colorName.text =
            '#${(result.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      });
    }
  }

  Future<void> _showDetails() async {
    final strings = XmlStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(strings.spoolDetails),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.save),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _detailField(widget.draft.manufacturer, strings.manufacturer),
              _detailField(widget.draft.commercialName, strings.commercialName),
              _detailField(
                widget.draft.diameter,
                strings.diameterMm,
                numeric: true,
              ),
              _detailField(
                widget.draft.originalWeight,
                strings.originalWeight,
                numeric: true,
                suffix: strings.grams,
              ),
              _detailField(
                widget.draft.tareWeight,
                strings.tareWeight,
                numeric: true,
                suffix: strings.grams,
              ),
              _detailField(
                widget.draft.purchaseDate,
                strings.purchaseDate,
                hint: strings.dateHint,
              ),
              _detailField(
                widget.draft.storageLocation,
                strings.storageLocation,
              ),
              _detailField(
                widget.draft.storageLocationCode,
                strings.storageLocationCode,
              ),
              _detailField(widget.draft.batchNumber, strings.batchNumber),
              _detailField(widget.draft.openPrintTagId, strings.openPrintTagId),
              _detailField(widget.draft.notes, strings.notes, lines: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    String? suffix,
    String? hint,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
      ),
    ),
  );
}

class _SlotDraft {
  _SlotDraft({
    this.id,
    required this.material,
    required this.colorName,
    required this.weight,
    required this.color,
    this.tagUid,
    this.tagInstanceId,
    this.tagBrand,
    this.tagFullWeightGrams,
    this.tagLastReadAt,
    required this.manufacturer,
    required this.commercialName,
    required this.diameter,
    required this.originalWeight,
    required this.tareWeight,
    required this.purchaseDate,
    required this.storageLocation,
    required this.storageLocationCode,
    required this.batchNumber,
    required this.openPrintTagId,
    required this.notes,
    this.serverSlotId,
    this.serverSlotVersion = 0,
    this.serverMaterialId,
    this.serverMaterialVersion = 0,
    this.serverSpoolId,
    this.serverSpoolVersion = 0,
    this.serverManufacturerId,
    this.serverManufacturerVersion = 0,
    this.serverLocationId,
    this.serverLocationVersion = 0,
  });

  factory _SlotDraft.empty() => _SlotDraft(
    material: TextEditingController(),
    colorName: TextEditingController(),
    weight: TextEditingController(text: '1000'),
    color: const Color(0xFF171717),
    manufacturer: TextEditingController(),
    commercialName: TextEditingController(),
    diameter: TextEditingController(text: '1.75'),
    originalWeight: TextEditingController(text: '1000'),
    tareWeight: TextEditingController(),
    purchaseDate: TextEditingController(),
    storageLocation: TextEditingController(),
    storageLocationCode: TextEditingController(),
    batchNumber: TextEditingController(),
    openPrintTagId: TextEditingController(),
    notes: TextEditingController(),
  );

  factory _SlotDraft.fromSlot(FilamentSlot slot) => _SlotDraft(
    id: slot.id,
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
    manufacturer: TextEditingController(text: slot.manufacturer),
    commercialName: TextEditingController(text: slot.commercialName),
    diameter: TextEditingController(text: slot.diameterMm.toString()),
    originalWeight: TextEditingController(
      text: slot.originalWeightGrams?.toString() ?? '',
    ),
    tareWeight: TextEditingController(
      text: slot.tareWeightGrams?.toString() ?? '',
    ),
    purchaseDate: TextEditingController(
      text: slot.purchaseDate?.toIso8601String().split('T').first ?? '',
    ),
    storageLocation: TextEditingController(text: slot.storageLocation),
    storageLocationCode: TextEditingController(text: slot.storageLocationCode),
    batchNumber: TextEditingController(text: slot.batchNumber),
    openPrintTagId: TextEditingController(text: slot.openPrintTagId),
    notes: TextEditingController(text: slot.notes),
    serverSlotId: slot.serverSlotId,
    serverSlotVersion: slot.serverSlotVersion,
    serverMaterialId: slot.serverMaterialId,
    serverMaterialVersion: slot.serverMaterialVersion,
    serverSpoolId: slot.serverSpoolId,
    serverSpoolVersion: slot.serverSpoolVersion,
    serverManufacturerId: slot.serverManufacturerId,
    serverManufacturerVersion: slot.serverManufacturerVersion,
    serverLocationId: slot.serverLocationId,
    serverLocationVersion: slot.serverLocationVersion,
  );

  final int? id;
  final TextEditingController material;
  final TextEditingController colorName;
  final TextEditingController weight;
  Color color;
  String? tagUid;
  String? tagInstanceId;
  String? tagBrand;
  double? tagFullWeightGrams;
  DateTime? tagLastReadAt;
  final TextEditingController manufacturer;
  final TextEditingController commercialName;
  final TextEditingController diameter;
  final TextEditingController originalWeight;
  final TextEditingController tareWeight;
  final TextEditingController purchaseDate;
  final TextEditingController storageLocation;
  final TextEditingController storageLocationCode;
  final TextEditingController batchNumber;
  final TextEditingController openPrintTagId;
  final TextEditingController notes;
  final String? serverSlotId;
  final int serverSlotVersion;
  final String? serverMaterialId;
  final int serverMaterialVersion;
  final String? serverSpoolId;
  final int serverSpoolVersion;
  final String? serverManufacturerId;
  final int serverManufacturerVersion;
  final String? serverLocationId;
  final int serverLocationVersion;

  void dispose() {
    material.dispose();
    colorName.dispose();
    weight.dispose();
    manufacturer.dispose();
    commercialName.dispose();
    diameter.dispose();
    originalWeight.dispose();
    tareWeight.dispose();
    purchaseDate.dispose();
    storageLocation.dispose();
    storageLocationCode.dispose();
    batchNumber.dispose();
    openPrintTagId.dispose();
    notes.dispose();
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
