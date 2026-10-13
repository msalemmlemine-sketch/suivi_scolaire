import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.s,
    required this.designer,
    required this.version,
    required this.onToggleLanguage,
  });
  final S s;
  final String designer, version;
  final VoidCallback onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.translate, color: AppColors.teal),
            title: Text(s.t('language')),
            subtitle: Text(s.t('language_value')),
            trailing: TextButton(onPressed: onToggleLanguage, child: Text(s.t('switch_language'))),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('about'), style: text.titleMedium),
              const SizedBox(height: 12),
              _Row(label: s.t('designed_by'), value: designer),
              const Divider(height: 24),
              _Row(label: s.t('version'), value: version),
              const Divider(height: 24),
              Text(s.t('offline_note'), style: text.bodySmall),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(children: [
      Expanded(child: Text(label, style: text.bodySmall)),
      Text(value, style: text.titleMedium),
    ]);
  }
}
