# Changelog

## 0.5.0+4 — Suivi comportemental et évaluations

- Added a bilingual Follow-up screen accessible from the More menu.
- Added behaviour observations with category, date, severity, description, action taken and teacher notes.
- Added assessment creation by class and subject with type, date, maximum score and coefficient.
- Added mark entry/editing with pending, graded, absent and exempt states.
- Preserved previous mark values through the existing SQLite history trigger.
- Added weighted per-student/per-subject averages normalized to 20; only graded results contribute in this phase.
- Historical enrollments remain visible for assessments that took place while the enrollment was valid.
- Added repository tests for behavior records, result history, zero marks, validation and weighted average calculations.
- Added the SQLite schema regression script to the CI workflow.

## Validation status

- `python3 tools/test_schema.py`: 24/24 passed in the authoring environment.
- `python3 tools/check_localization.py`: 166 used keys, no missing translations; 176 bilingual entries.
- Weighted-average SQL was checked with a SQLite sample (13.75/20 expected and obtained).
- Flutter/Dart commands (`dart format`, `flutter analyze`, `flutter test`, `flutter build apk`) could not be executed in the authoring environment because Flutter and Dart are not installed. Do not consider the APK build validated until CI or a Flutter-equipped machine completes these commands.

## 0.6.0 — UI consistency pass
- Standardized Material 3 typography, cards, form fields, buttons, app bar, and navigation bar.
- Rebuilt the More screen to avoid narrow ListTile layouts and broken Arabic/French line wrapping.
- Improved dashboard heading contrast and quick-action labels.
- Preserved the SQLite schema and existing repository/business logic.

## 0.6.0+5 — audit pass (no schema change)
- pubspec version aligned with kAppVersion/CHANGELOG (was 0.5.0+4); Dart SDK floor raised to 3.6 (Column.spacing, Color.withValues).
- Follow-up dialogs: uniform 12 px field spacing.
- Replaced deprecated Color.withOpacity with withValues.
- README localization counts corrected; added AUDIT.md.
- Not verified: flutter analyze/test/build, visual layout.
