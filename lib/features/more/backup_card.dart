import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../core/services/backup_service.dart';

class BackupCard extends StatefulWidget {
  const BackupCard({super.key, required this.db, required this.s});
  final Database db;
  final S s;

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _busy = false;

  void _snack(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t(key))));
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      await BackupService.exportBackup(widget.db);
    } catch (_) {
      _snack('backup_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final s = widget.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t('backup_restore')),
        content: Text(s.t('restore_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final done = await BackupService.restoreBackup(widget.db);
      if (!done || !mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(s.t('backup_restore')),
            content: Text(s.t('restore_done')),
            actions: [FilledButton(onPressed: () => SystemNavigator.pop(), child: Text(s.t('close_app')))],
          ),
        ),
      );
    } on BackupException catch (e) {
      _snack(e.message == 'too_new' ? 'restore_too_new' : 'restore_invalid');
    } catch (_) {
      _snack('backup_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.backup_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(s.t('backup_title'), style: text.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text(s.t('backup_hint'), style: text.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(onPressed: _busy ? null : _backup, icon: const Icon(Icons.ios_share), label: Text(s.t('backup_export'))),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: _busy ? null : _restore, icon: const Icon(Icons.restore), label: Text(s.t('backup_restore'))),
          ),
        ]),
      ),
    );
  }
}
