import 'package:sqflite/sqflite.dart';

import '../core/errors/app_exception.dart';
import '../models/institution.dart';

/// Institutions are never deleted: they are archived and can be restored,
/// so historical classes, enrollments and grades stay intact.
class InstitutionRepository {
  InstitutionRepository(this._db);
  final Database _db;

  Future<List<Institution>> list({required bool archived}) async {
    final rows = await _db.query('institutions',
        where: 'status = ?',
        whereArgs: [archived ? 'archived' : 'active'],
        orderBy: 'id');
    return rows.map(Institution.fromMap).toList();
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, Object?> _values({
    String? nameAr,
    String? nameFr,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? notes,
  }) {
    final ar = _clean(nameAr), fr = _clean(nameFr);
    if (ar == null && fr == null) throw const AppException(ErrorCodes.nameRequired);
    return {
      'name_ar': ar,
      'name_fr': fr,
      'short_name': _clean(shortName),
      'address': _clean(address),
      'phone': _clean(phone),
      'email': _clean(email),
      'notes': _clean(notes),
    };
  }

  Future<int> add({
    String? nameAr,
    String? nameFr,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? notes,
  }) =>
      _db.insert(
          'institutions',
          _values(
              nameAr: nameAr,
              nameFr: nameFr,
              shortName: shortName,
              address: address,
              phone: phone,
              email: email,
              notes: notes));

  Future<void> update(
    int id, {
    String? nameAr,
    String? nameFr,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? notes,
  }) async {
    await _db.update(
        'institutions',
        _values(
            nameAr: nameAr,
            nameFr: nameFr,
            shortName: shortName,
            address: address,
            phone: phone,
            email: email,
            notes: notes),
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> setArchived(int id, bool archived) async {
    await _db.update('institutions', {'status': archived ? 'archived' : 'active'},
        where: 'id = ?', whereArgs: [id]);
  }
}
