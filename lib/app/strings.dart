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
    'timetable_short': {'ar': 'الحصص', 'fr': 'Planning'},
    'add_institution': {'ar': 'إضافة مؤسسة', 'fr': 'Ajouter un établissement'},
    'edit_institution': {'ar': 'تعديل المؤسسة', 'fr': 'Modifier l’établissement'},
    'name_ar': {'ar': 'اسم المؤسسة بالعربية', 'fr': 'Nom en arabe'},
    'name_fr': {'ar': 'اسم المؤسسة بالفرنسية', 'fr': 'Nom en français'},
    'short_name': {'ar': 'الاسم المختصر', 'fr': 'Nom court'},
    'address': {'ar': 'العنوان', 'fr': 'Adresse'},
    'phone': {'ar': 'الهاتف', 'fr': 'Téléphone'},
    'email': {'ar': 'البريد الإلكتروني', 'fr': 'E-mail'},
    'notes': {'ar': 'ملاحظات', 'fr': 'Notes'},
    'save': {'ar': 'حفظ', 'fr': 'Enregistrer'},
    'cancel': {'ar': 'إلغاء', 'fr': 'Annuler'},
    'archive': {'ar': 'أرشفة', 'fr': 'Archiver'},
    'restore': {'ar': 'استعادة', 'fr': 'Restaurer'},
    'edit': {'ar': 'تعديل', 'fr': 'Modifier'},
    'tab_active': {'ar': 'النشطة', 'fr': 'Actifs'},
    'tab_archived': {'ar': 'المؤرشفة', 'fr': 'Archivés'},
    'err_name_required': {
      'ar': 'أدخل اسم المؤسسة بالعربية أو الفرنسية.',
      'fr': 'Saisissez le nom en arabe ou en français.'
    },
    'err_unknown': {'ar': 'تعذر تنفيذ العملية.', 'fr': 'Opération impossible.'},
    'no_inst_title': {'ar': 'لا توجد مؤسسات بعد', 'fr': 'Aucun établissement'},
    'no_inst_body': {
      'ar': 'أضف مؤسستك الأولى للبدء، ثم أنشئ السنة الدراسية والأقسام.',
      'fr': 'Ajoutez votre premier établissement pour commencer.'
    },
    'no_archived': {'ar': 'لا توجد مؤسسات مؤرشفة', 'fr': 'Aucun établissement archivé'},
    'archive_confirm': {
      'ar': 'ستُخفى المؤسسة من القوائم دون حذف أي بيانات، ويمكن استعادتها لاحقًا.',
      'fr': 'L’établissement sera masqué sans supprimer de données ; vous pourrez le restaurer.'
    },
    'ui_language': {'ar': 'لغة الواجهة', 'fr': 'Langue de l’interface'},
    'report_language': {'ar': 'لغة القوائم والتقارير', 'fr': 'Langue des listes et rapports'},
    'report_language_hint': {
      'ar': 'مستقلة عن لغة الواجهة (الافتراضية: الفرنسية).',
      'fr': 'Indépendante de la langue de l’interface (par défaut : français).'
    },
    'lang_ar': {'ar': 'العربية', 'fr': 'العربية'},
    'lang_fr': {'ar': 'Français', 'fr': 'Français'},
    'err_required': {'ar': 'أكمل الحقول المطلوبة.', 'fr': 'Complétez les champs obligatoires.'},
    'err_invalid_dates': {'ar': 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية (YYYY-MM-DD).', 'fr': 'La date de fin doit suivre la date de début (AAAA-MM-JJ).'},
    'err_class_exists': {'ar': 'يوجد قسم بهذا الاسم في هذه السنة.', 'fr': 'Une classe de ce nom existe déjà cette année.'},
    'err_student_already_active_in_year': {'ar': 'التلميذ مسجل تسجيلًا نشطًا في هذه السنة الدراسية.', 'fr': 'Cet élève a déjà une inscription active cette année.'},
    'err_enrollment_not_active': {'ar': 'لا يوجد تسجيل نشط لهذا التلميذ.', 'fr': 'Aucune inscription active pour cet élève.'},
    'school_year': {'ar': 'السنة الدراسية', 'fr': 'Année scolaire'},
    'add_year': {'ar': 'إضافة سنة', 'fr': 'Ajouter une année'},
    'year_name': {'ar': 'اسم السنة (مثال: 2026-2027)', 'fr': 'Nom (ex. 2026-2027)'},
    'start_date': {'ar': 'البداية (YYYY-MM-DD)', 'fr': 'Début (AAAA-MM-JJ)'},
    'end_date': {'ar': 'النهاية (YYYY-MM-DD)', 'fr': 'Fin (AAAA-MM-JJ)'},
    'active_year': {'ar': 'نشطة', 'fr': 'active'},
    'set_active_year': {'ar': 'اعتماد كسنة نشطة', 'fr': 'Définir comme année active'},
    'no_year_title': {'ar': 'لا توجد سنة دراسية', 'fr': 'Aucune année scolaire'},
    'no_year_body': {'ar': 'أضف السنة الدراسية لهذه المؤسسة لتتمكن من إنشاء الأقسام.', 'fr': 'Ajoutez une année scolaire pour créer des classes.'},
    'classes': {'ar': 'الأقسام', 'fr': 'Classes'},
    'add_class': {'ar': 'إضافة قسم', 'fr': 'Ajouter une classe'},
    'edit_class': {'ar': 'تعديل القسم', 'fr': 'Modifier la classe'},
    'class_name_fr': {'ar': 'اسم القسم بالفرنسية (مثال: 6AS-C)', 'fr': 'Nom (ex. 6AS-C)'},
    'class_name_ar': {'ar': 'اسم القسم بالعربية', 'fr': 'Nom en arabe'},
    'level': {'ar': 'المستوى', 'fr': 'Niveau'},
    'no_classes': {'ar': 'لا توجد أقسام في هذه السنة بعد.', 'fr': 'Aucune classe cette année.'},
    'students_count': {'ar': 'تلميذ', 'fr': 'élève(s)'},
    'show_archived': {'ar': 'عرض المؤرشفة', 'fr': 'Afficher archivées'},
    'search': {'ar': 'بحث بالاسم أو الرقم', 'fr': 'Rechercher nom ou matricule'},
    'all_classes': {'ar': 'كل الأقسام', 'fr': 'Toutes'},
    'add_student': {'ar': 'إضافة تلميذ', 'fr': 'Ajouter un élève'},
    'edit_student': {'ar': 'تعديل التلميذ', 'fr': 'Modifier l’élève'},
    'family_name': {'ar': 'اللقب (بالفرنسية)', 'fr': 'Nom de famille'},
    'given_name': {'ar': 'الاسم الشخصي (بالفرنسية)', 'fr': 'Prénom'},
    'full_name_ar': {'ar': 'الاسم الكامل بالعربية', 'fr': 'Nom complet en arabe'},
    'matricule': {'ar': 'رقم التسجيل', 'fr': 'Matricule'},
    'gender': {'ar': 'الجنس', 'fr': 'Sexe'},
    'male': {'ar': 'ذكر', 'fr': 'Garçon'},
    'female': {'ar': 'أنثى', 'fr': 'Fille'},
    'guardian_name': {'ar': 'اسم الولي', 'fr': 'Tuteur'},
    'guardian_phone': {'ar': 'هاتف الولي', 'fr': 'Téléphone du tuteur'},
    'class_label': {'ar': 'القسم', 'fr': 'Classe'},
    'transfer': {'ar': 'نقل', 'fr': 'Transférer'},
    'end_enrollment': {'ar': 'إنهاء التسجيل', 'fr': 'Terminer l’inscription'},
    'end_confirm': {'ar': 'سيُنهى التسجيل ويبقى السجل التاريخي محفوظًا.', 'fr': 'L’inscription sera clôturée ; l’historique est conservé.'},
    'transfer_to': {'ar': 'النقل إلى', 'fr': 'Transférer vers'},
    'no_students_title': {'ar': 'لا يوجد تلاميذ', 'fr': 'Aucun élève'},
    'no_students_body': {'ar': 'أضف التلاميذ يدويًا، أو استوردهم من Excel لاحقًا.', 'fr': 'Ajoutez des élèves manuellement.'},
    'need_class_title': {'ar': 'أنشئ قسمًا أولًا', 'fr': 'Créez d’abord une classe'},
    'need_class_body': {'ar': 'افتح المؤسسة، أضف السنة الدراسية ثم الأقسام، ثم عد لتسجيل التلاميذ.', 'fr': 'Ouvrez l’établissement, ajoutez l’année puis les classes.'},
    'go_institutions': {'ar': 'الذهاب إلى المؤسسات', 'fr': 'Aller aux établissements'},
    'institution': {'ar': 'المؤسسة', 'fr': 'Établissement'},
    'year_prefix': {'ar': 'السنة', 'fr': 'Année'},
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
