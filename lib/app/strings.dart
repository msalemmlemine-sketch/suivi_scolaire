/// Interim UI strings (ar/fr). Replaced by gen_l10n ARB files in the
/// localisation phase; keys are kept stable so the swap is mechanical.
class S {
  const S(this.code);
  final String code;
  bool get isAr => code == 'ar';
  String t(String key) => _m[key]?[code] ?? key;

  static const Map<String, Map<String, String>> _m = {
    'app_title': {'ar': 'متابعة التلاميذ', 'fr': 'Suivi Scolaire'},
    'home': {'ar': 'الرئيسية', 'fr': 'Accueil'},
    'institutions': {'ar': 'المؤسسات', 'fr': 'Établissements'},
    'students': {'ar': 'التلاميذ', 'fr': 'Élèves'},
    'timetable': {'ar': 'جدول الحصص', 'fr': 'Emploi du temps'},
    'more': {'ar': 'المزيد', 'fr': 'Plus'},
    'hello': {'ar': 'مرحبًا أستاذ', 'fr': 'Bonjour'},
    'no_institution': {
      'ar': 'لم تُضف أي مؤسسة بعد',
      'fr': 'Aucun établissement ajouté'
    },
    'overview': {'ar': 'نظرة عامة', 'fr': 'Vue d’ensemble'},
    'stat_institutions': {'ar': 'مؤسسات', 'fr': 'Établ.'},
    'stat_classes': {'ar': 'أقسام', 'fr': 'Classes'},
    'stat_students': {'ar': 'تلاميذ', 'fr': 'Élèves'},
    'quick_access': {'ar': 'وصول سريع', 'fr': 'Accès rapide'},
    'today_sessions': {'ar': 'حصص اليوم', 'fr': 'Séances du jour'},
    'no_sessions': {
      'ar': 'لا توجد حصص مقررة اليوم',
      'fr': 'Aucune séance prévue aujourd’hui'
    },
    'follow_up': {'ar': 'تلاميذ يحتاجون متابعة', 'fr': 'Élèves à suivre'},
    'no_follow_up': {
      'ar': 'ستظهر هنا حالات الغياب المتكرر والتعثر',
      'fr': 'Les absences répétées et difficultés apparaîtront ici'
    },
    'coming_title': {'ar': 'هذه الشاشة قيد البناء', 'fr': 'Écran en construction'},
    'coming_body': {
      'ar': 'تتوفر في التحديث القادم. البيانات المحفوظة لن تتأثر.',
      'fr': 'Disponible à la prochaine mise à jour. Vos données ne seront pas affectées.'
    },
    'language': {'ar': 'اللغة', 'fr': 'Langue'},
    'language_value': {'ar': 'العربية', 'fr': 'Français'},
    'switch_language': {'ar': 'Passer en français', 'fr': 'التبديل إلى العربية'},
    'about': {'ar': 'حول التطبيق', 'fr': 'À propos'},
    'designed_by': {'ar': 'تصميم وإعداد', 'fr': 'Conçu par'},
    'version': {'ar': 'الإصدار', 'fr': 'Version'},
    'offline_note': {
      'ar': 'يعمل دون إنترنت — بياناتك محفوظة على هاتفك فقط.',
      'fr': 'Fonctionne hors ligne — vos données restent sur ce téléphone.'
    },
  };
}
