enum EnrollmentStatus { active, transferred, ended, archived }

class Enrollment {
  const Enrollment({
    required this.id,
    required this.studentId,
    required this.institutionId,
    required this.academicYearId,
    required this.classId,
    required this.status,
    required this.startDate,
    this.endDate,
    this.endReason,
  });

  final int id, studentId, institutionId, academicYearId, classId;
  final EnrollmentStatus status;
  final String startDate; // ISO yyyy-MM-dd
  final String? endDate, endReason;

  factory Enrollment.fromMap(Map<String, Object?> m) => Enrollment(
        id: m['id'] as int,
        studentId: m['student_id'] as int,
        institutionId: m['institution_id'] as int,
        academicYearId: m['academic_year_id'] as int,
        classId: m['class_id'] as int,
        status: EnrollmentStatus.values.byName(m['status'] as String),
        startDate: m['start_date'] as String,
        endDate: m['end_date'] as String?,
        endReason: m['end_reason'] as String?,
      );
}
