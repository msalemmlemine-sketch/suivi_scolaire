/// One migration = one SQL asset. Statements are separated by a line
/// containing only `-- @@` (trigger bodies contain semicolons).
/// Rules: never edit a released migration; add a new file + entry instead;
/// never drop/recreate the database to "fix" an upgrade.
class Migration {
  const Migration(this.version, this.asset);
  final int version;
  final String asset;
}

const List<Migration> kMigrations = [
  Migration(1, 'assets/sql/001_initial.sql'),
];

int get kLatestSchemaVersion => kMigrations.last.version;

const String kStatementSeparator = '\n-- @@\n';

List<String> splitStatements(String sql) => sql
    .replaceAll('\r\n', '\n')
    .split(kStatementSeparator)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
