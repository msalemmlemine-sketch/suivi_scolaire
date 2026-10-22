import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/institutions/institutions_page.dart';
import '../features/students/students_page.dart';
import '../features/timetable/timetable_page.dart';
import '../features/more/more_page.dart';
import '../features/followup/followup_page.dart';
import 'strings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.db, required this.s, required this.designer, required this.version, required this.onToggleLanguage});
  final Database db;
  final S s;
  final String designer, version;
  final VoidCallback onToggleLanguage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  // IndexedStack keeps every tab alive, so a page would keep the data it loaded
  // at startup. Bumping a tab's generation re-creates it with fresh data.
  final List<int> _gen = List<int>.filled(5, 0);

  void _openTab(int i) => setState(() {
        if (i >= 0 && i < 4) _gen[i]++;
        _tab = i;
      });

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final titles = [s.t('app_title'), s.t('institutions'), s.t('students'), s.t('timetable'), s.t('more')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab], maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _tab, children: [
          DashboardPage(key: ValueKey('dash${_gen[0]}'), db: widget.db, s: s, onOpenTab: _openTab),
          InstitutionsPage(key: ValueKey('inst${_gen[1]}'), db: widget.db, s: s),
          StudentsPage(key: ValueKey('stud${_gen[2]}'), db: widget.db, s: s),
          TimetablePage(key: ValueKey('tt${_gen[3]}'), db: widget.db, s: s),
          MorePage(
            db: widget.db, s: s, designer: widget.designer, version: widget.version,
            onToggleLanguage: widget.onToggleLanguage,
            onOpenFollowup: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(appBar: AppBar(title: Text(s.t('followup'))), body: FollowupPage(db: widget.db, s: s)),
            )),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _openTab,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard_rounded), label: s.t('home')),
          NavigationDestination(icon: const Icon(Icons.account_balance_outlined), selectedIcon: const Icon(Icons.account_balance_rounded), label: s.t('institutions')),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups_rounded), label: s.t('students')),
          NavigationDestination(icon: const Icon(Icons.calendar_view_week_outlined), selectedIcon: const Icon(Icons.calendar_view_week_rounded), label: s.t('timetable')),
          NavigationDestination(icon: const Icon(Icons.tune_rounded), selectedIcon: const Icon(Icons.tune_rounded), label: s.t('more')),
        ],
      ),
    );
  }
}
