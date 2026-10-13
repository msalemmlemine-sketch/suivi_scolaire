import 'package:sqflite/sqflite.dart';

/// Local-only institution CRUD. Historical references are preserved by SQLite
/// RESTRICT constraints; archiving is preferred over deletion.
class InstitutionRepository {
  InstitutionRepository(this._db);
  final Database _db;

  Future<List<Map<String, Object?>>> list({bool includeArchived = false}) =>
      _db.rawQuery('''
        SELECT i.*, COUNT(DISTINCT c.id) AS class_count,
               COUNT(DISTINCT CASE WHEN e.status = 'active' THEN e.student_id END) AS student_count
        FROM institutions i
        LEFT JOIN classes c ON c.institution_id = i.id AND c.status = 'active'
        LEFT JOIN enrollments e ON e.institution_id = i.id AND e.status = 'active'
        ${includeArchived ? '' : "WHERE i.status = 'active'"}
        GROUP BY i.id
        ORDER BY i.status, COALESCE(NULLIF(i.name_fr, ''), i.name_ar), i.id
      ''');

  Future<int> save({
    int? id,
    required String nameAr,
    required String nameFr,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final ar = nameAr.trim();
    final fr = nameFr.trim();
    if (ar.isEmpty && fr.isEmpty) throw ArgumentError('institution_name_required');
    final values = <String, Object?>{
      'name_ar': ar.isEmpty ? null : ar,
      'name_fr': fr.isEmpty ? null : fr,
      'short_name': _nullIfBlank(shortName),
      'address': _nullIfBlank(address),
      'phone': _nullIfBlank(phone),
      'email': _nullIfBlank(email),
      'notes': _nullIfBlank(notes),
    };
    if (id == null) return _db.insert('institutions', values);
    await _db.update('institutions', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> setArchived(int id, bool archived) async {
    await _db.update('institutions', {'status': archived ? 'archived' : 'active'},
        where: 'id = ?', whereArgs: [id]);
  }

  String? _nullIfBlank(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
