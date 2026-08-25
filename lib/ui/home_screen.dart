import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../localization/xml_strings.dart';
import '../models/filament_slot.dart';
import '../models/printer_record.dart';
import 'printer_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _openEditor(BuildContext context, [PrinterRecord? printer]) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PrinterEditorScreen(
          controller: controller,
          printer: printer,
          allowNameEditing: printer == null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.printers),
        actions: [
          IconButton(
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 3
                : constraints.maxWidth >= 650
                ? 2
                : 1;
            final padding = constraints.maxWidth >= 650 ? 24.0 : 16.0;
            if (columns == 1) {
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 100),
                itemCount: controller.printers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => PrinterCard(
                  printer: controller.printers[index],
                  onTap: () => _openEditor(context, controller.printers[index]),
                ),
              );
            }
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 210,
              ),
              itemCount: controller.printers.length,
              itemBuilder: (context, index) => PrinterCard(
                printer: controller.printers[index],
                onTap: () => _openEditor(context, controller.printers[index]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: Text(strings.addPrinter),
      ),
    );
  }
}

class PrinterCard extends StatelessWidget {
  const PrinterCard({super.key, required this.printer, required this.onTap});

  final PrinterRecord printer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.precision_manufacturing,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      printer.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              if (printer.slots.isEmpty)
                Text(strings.noFilaments)
              else
                for (
                  var index = 0;
                  index < printer.slots.length && index < 3;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _FilamentRow(slot: printer.slots[index]),
                ],
              if (printer.slots.length > 3)
                Text(
                  '+${printer.slots.length - 3}',
                  style: TextStyle(color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilamentRow extends StatelessWidget {
  const _FilamentRow({required this.slot});

  final FilamentSlot slot;

  @override
  Widget build(BuildContext context) {
    final strings = XmlStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final weight = slot.remainingGrams == slot.remainingGrams.roundToDouble()
        ? slot.remainingGrams.toInt().toString()
        : slot.remainingGrams.toStringAsFixed(1);
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Color(slot.colorValue),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '${slot.material} · ${slot.colorName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          strings.weightValue(weight),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
