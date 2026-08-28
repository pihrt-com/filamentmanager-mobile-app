# Changelog

## 1.3.1 - 2026-08-28

- Automatically attempts a non-blocking synchronization after saving or deleting a printer and after unloading a spool.
- Keeps changes in the persistent offline queue when the server or network is unavailable, ready for the next automatic or manual synchronization.
- Corrected the current version information in the README.
- Increased the Android application version to 1.3.1 (build 10).

## 1.3.0 - 2026-08-28

- Added pull-to-refresh synchronization to the printer overview in portrait and landscape layouts.
- Added a cloud indicator that shows whether server synchronization is disabled, online, offline, or still being checked.
- Added localized printer operational-state badges and unavailable-card styling matching the server dashboard.
- Added an action to unload a spool from a printer while retaining it in server inventory.
- Removed fractional seconds from the last-synchronization time shown in Settings.
- Updated the README with the current server relationship, synchronization controls, independent ordering behavior, administrator device management, and cross-repository documentation links.
- Increased the Android application version to 1.3.0 (build 9).

## 1.2.4 - 2026-08-28

- Fixed both conflict-resolution choices so the selected phone or server version is actually applied.
- Preserved the original pending mutation when the server resolves a natural-key collision to its canonical entity ID.
- Added recovery for printer-slot conflicts already stored by version 1.2.3 without their local payload.
- Refreshed and persisted the displayed FilamentManager Server version during every synchronization.
- Increased the Android application version to 1.2.4 (build 8).

## 1.2.3 - 2026-08-28

- Distinguished an internal server error from an unreachable server during synchronization.
- Displayed the safe server request identifier for HTTP 5xx responses so administrators can match a mobile error with the server log.
- Parsed the server API's nested error envelope and safely handled non-JSON error pages without hiding the original HTTP status.
- Increased the Android application version to 1.2.3 (build 7).

## 1.2.2 - 2026-08-28

- Added one stable UUID per app installation so repeated sign-ins update the same server device instead of creating duplicate rows.
- Moved server credentials into an isolated Android secure-storage namespace to avoid legacy cipher-migration failures.
- Stored and verified the access and refresh tokens as one atomic encrypted session record and retained an in-memory session cache while the app is running.
- Automatically returns the server card to the sign-in form when Android secure storage no longer contains a usable session.
- Increased the Android application version to 1.2.2 (build 6).

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

- Added OpenPrintTag NFC-V reading and remaining-weight writing verified against the official test vector; physical Prusa spool validation remains pending.
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
