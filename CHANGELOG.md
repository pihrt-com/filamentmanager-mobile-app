# Changelog

## 1.2.1 - 2026-08-28

- Prevented simultaneous automatic and manual synchronization from refreshing authentication more than once.
- Added one safe authentication retry when downloading a server snapshot returns HTTP 401.
- Added sanitized REST diagnostics containing only the HTTP method, endpoint path, and response status; credentials and tokens are never logged.
- Replaced technical HTTP errors in the interface with clear localized explanations and suggested next steps.
- Increased the Android application version to 1.2.1 (build 5).

## 1.2.0 - 2026-08-28

- Added optional connection to a self-hosted FilamentManager Server with secure token storage.
- Added explicit first synchronization choices: upload to an empty server, download with a local safety backup, or merge with a duplicate-name preview.
- Added persistent offline mutation queue, bidirectional synchronization, rotating access tokens, version conflicts, and phone/server conflict resolution.
- Added manufacturer, commercial name, diameter, original and tare weights, purchase date, storage location, batch, OpenPrintTag ID, and notes to filament positions.
- Added a custom RGB color picker with a live HEX preview while retaining the preset color palette.
- Simplified NFC controls in the printer editor and retained the central OpenPrintTag link in Settings.
- Added links to both the mobile and server GitHub repositories in Settings and README.
- Increased the Android application version to 1.2.0 (build 4).

## 1.1.0 - 2026-08-26

- Added OpenPrintTag NFC-V reading and verified remaining-weight writing.
- Added natural alphabetical and custom drag-and-drop printer sorting.
- Displayed every loaded filament position on printer cards.

## 1.0.1 - 2026-08-25

- Fixed printer cards not being rendered in portrait orientation.
- Added a portrait-layout regression test for saved printers and filaments.
- Added editable material autocomplete with a catalog of common filament types.

## 1.0.0 - 2026-08-25

- Added responsive printer overview for portrait and landscape layouts.
- Added unlimited loaded-filament positions per printer.
- Added material, color, color marker, and remaining-weight editing.
- Added local SQLite persistence.
- Added versioned JSON export and import with replace or add modes.
- Added English and Czech XML localization catalogs.
- Added light, dark, and system themes.
- Added application information, author, website, version, release date, and
  GitHub links in Settings.
- Added original application artwork and Android adaptive icons.
- Prepared the application architecture for future OpenPrintTag NFC support.
