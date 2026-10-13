/// Domain error with a stable [code] the UI maps to a translated message
/// (never show raw SQL errors to the user).
class AppException implements Exception {
  const AppException(this.code, [this.details]);
  final String code;
  final String? details;
  @override
  String toString() => 'AppException($code${details == null ? '' : ': $details'})';
}

class ErrorCodes {
  static const studentAlreadyActive = 'student_already_active_in_year';
  static const classMismatch = 'class_institution_year_mismatch';
  static const notActive = 'enrollment_not_active';
  static const classNotFound = 'class_not_found';
  static const nameRequired = 'name_required';
  static const unknown = 'unknown';
}
