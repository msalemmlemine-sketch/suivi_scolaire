class YearLink {
  const YearLink({required this.id, required this.name, required this.startDate, required this.endDate, required this.isActive});
  final int id;
  final String name, startDate, endDate;
  final bool isActive;
}

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.institutionId,
    required this.yearId,
    required this.nameFr,
    this.nameAr,
    this.level,
    this.status = 'active',
    this.studentCount = 0,
  });
  final int id, institutionId, yearId, studentCount;
  final String nameFr;
  final String? nameAr, level;
  final String status;

  bool get isArchived => status == 'archived';

  String displayName(bool ar) =>
      ar && (nameAr?.trim().isNotEmpty ?? false) ? nameAr!.trim() : nameFr;

  factory SchoolClass.fromMap(Map<String, Object?> m) => SchoolClass(
        id: m['id'] as int,
        institutionId: m['institution_id'] as int,
        yearId: m['academic_year_id'] as int,
        nameFr: m['name_fr'] as String,
        nameAr: m['name_ar'] as String?,
        level: m['level'] as String?,
        status: (m['status'] as String?) ?? 'active',
        studentCount: (m['student_count'] as int?) ?? 0,
      );
}

class Student {
  const Student({
    required this.id,
    this.matricule,
    this.familyNameFr,
    this.givenNameFr,
    this.fullNameAr,
    this.gender,
    this.guardianName,
    this.guardianPhone,
  });
  final int id;
  final String? matricule, familyNameFr, givenNameFr, fullNameAr, gender, guardianName, guardianPhone;

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  String get frenchName => '${(familyNameFr ?? '').trim()} ${(givenNameFr ?? '').trim()}'.trim();

  /// Name in the preferred language, falling back to the other one.
  String displayName(bool ar) {
    final a = _has(fullNameAr) ? fullNameAr!.trim() : '';
    final f = frenchName;
    return ar ? (a.isNotEmpty ? a : f) : (f.isNotEmpty ? f : a);
  }

  factory Student.fromMap(Map<String, Object?> m) => Student(
        id: m['id'] as int,
        matricule: m['matricule'] as String?,
        familyNameFr: m['family_name_fr'] as String?,
        givenNameFr: m['given_name_fr'] as String?,
        fullNameAr: m['full_name_ar'] as String?,
        gender: m['gender'] as String?,
        guardianName: m['guardian_name'] as String?,
        guardianPhone: m['guardian_phone'] as String?,
      );
}

/// A student with the active enrollment shown in the students list.
class EnrolledStudent {
  const EnrolledStudent({required this.student, required this.enrollmentId, required this.classId, required this.className});
  final Student student;
  final int enrollmentId, classId;
  final String className;
}
