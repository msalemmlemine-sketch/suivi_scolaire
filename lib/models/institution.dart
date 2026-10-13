class Institution {
  const Institution({
    required this.id,
    this.nameAr,
    this.nameFr,
    this.shortName,
    this.address,
    this.phone,
    this.email,
    this.notes,
    this.status = 'active',
  });

  final int id;
  final String? nameAr, nameFr, shortName, address, phone, email, notes;
  final String status;

  bool get isArchived => status == 'archived';

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  /// Name in the preferred language, falling back to the other one.
  String displayName(bool ar) {
    final a = _has(nameAr) ? nameAr!.trim() : null;
    final f = _has(nameFr) ? nameFr!.trim() : null;
    return (ar ? (a ?? f) : (f ?? a)) ?? '';
  }

  factory Institution.fromMap(Map<String, Object?> m) => Institution(
        id: m['id'] as int,
        nameAr: m['name_ar'] as String?,
        nameFr: m['name_fr'] as String?,
        shortName: m['short_name'] as String?,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        notes: m['notes'] as String?,
        status: (m['status'] as String?) ?? 'active',
      );
}
