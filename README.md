# Suivi Scolaire — متابعة التلاميذ

Status: phases 1-2 (skeleton + database) plus UI phases: design fixes, Institutions, academic years, classes, students (add/edit/search/transfer/end). Grades engine, attendance, import/export, backup NOT built yet. Dart is NOT compiled locally; CI runs analyze, test, build.

Verified here: `python3 tools/test_schema.py` → 24/24 (real SQLite 3.45).
NOT verified here (Flutter/Dart not installed in the authoring sandbox):
`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk`.
The Dart files were never compiled; run those commands first on your machine.

Run: `flutter pub get && flutter analyze && flutter test` (from the project root).
