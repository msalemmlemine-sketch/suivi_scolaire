import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';

class DashboardStats {
  const DashboardStats(this.institutions, this.classes, this.students, this.firstInstitution);
  final int institutions, classes, students;
  final String? firstInstitution;
}

Future<DashboardStats> loadDashboardStats(Database db, bool ar) async {
  Future<int> count(String sql) async => Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
  final inst = await count("SELECT COUNT(*) FROM institutions WHERE status = 'active'");
  final cls = await count("SELECT COUNT(*) FROM classes WHERE status = 'active'");
  final stu = await count("SELECT COUNT(DISTINCT student_id) FROM enrollments WHERE status = 'active'");
  final rows = await db.rawQuery(
      "SELECT name_ar, name_fr FROM institutions WHERE status = 'active' ORDER BY id LIMIT 1");
  String? name;
  if (rows.isNotEmpty) {
    final a = rows.first['name_ar'] as String?;
    final f = rows.first['name_fr'] as String?;
    name = ar ? (a?.trim().isNotEmpty == true ? a : f) : (f?.trim().isNotEmpty == true ? f : a);
  }
  return DashboardStats(inst, cls, stu, name);
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.db, required this.s, required this.onOpenTab});
  final Database db;
  final S s;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardStats>(
      future: loadDashboardStats(db, s.isAr),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final st = snap.data ?? const DashboardStats(0, 0, 0, null);
        final text = Theme.of(context).textTheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Hero(s: s, institution: st.firstInstitution),
            const SizedBox(height: 16),
            Text(s.t('overview'), style: text.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: IntrinsicHeight(
                  child: Row(children: [
                    _Stat(value: st.institutions, label: s.t('stat_institutions')),
                    const VerticalDivider(),
                    _Stat(value: st.classes, label: s.t('stat_classes')),
                    const VerticalDivider(),
                    _Stat(value: st.students, label: s.t('stat_students')),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(s.t('quick_access'), style: text.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              _Quick(icon: Icons.account_balance_outlined, label: s.t('institutions'), onTap: () => onOpenTab(1)),
              const SizedBox(width: 10),
              _Quick(icon: Icons.groups_outlined, label: s.t('students'), onTap: () => onOpenTab(2)),
              const SizedBox(width: 10),
              _Quick(icon: Icons.calendar_view_week_outlined, label: s.t('timetable'), onTap: () => onOpenTab(3)),
            ]),
            const SizedBox(height: 20),
            _Section(title: s.t('today_sessions'), message: s.t('no_sessions'), icon: Icons.event_available_outlined),
            const SizedBox(height: 12),
            _Section(title: s.t('follow_up'), message: s.t('no_follow_up'), icon: Icons.flag_outlined),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.s, required this.institution});
  final S s;
  final String? institution;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.tealDark, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(width: 4, height: 52, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('hello'), style: text.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              institution ?? s.t('no_institution'),
              style: text.titleLarge?.copyWith(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$value', style: text.titleLarge?.copyWith(color: AppColors.teal, fontSize: 26)),
        const SizedBox(height: 2),
        Text(label, style: text.bodySmall),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(children: [
              Icon(icon, color: AppColors.teal, size: 28),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center, maxLines: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.message, required this.icon});
  final String title, message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: 2),
              Text(message, style: text.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}
