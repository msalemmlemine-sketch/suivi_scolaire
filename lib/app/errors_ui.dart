import '../core/errors/app_exception.dart';
import 'strings.dart';

/// Maps any thrown error to a translated, user-safe message
/// (raw SQL errors are never shown).
String errorMessage(S s, Object e) {
  if (e is AppException) {
    final key = e.code == ErrorCodes.nameRequired ? 'err_name_required' : 'err_${e.code}';
    final msg = s.t(key);
    if (msg != key) return msg;
  }
  return s.t('err_unknown');
}
