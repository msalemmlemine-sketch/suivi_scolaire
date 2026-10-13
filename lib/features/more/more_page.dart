import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.s,
    required this.designer,
    required this.version,
    required this.reportLanguage,
    required this.onSetUiLanguage,
    required this.onSetReportLanguage,
  });
  final S s;
  final String designer, version;
  final String reportLanguage;
  final ValueChanged<String> onSetUiLanguage, onSetReportLanguage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.translate, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text(s.t('ui_language'), style: text.titleMedium)),
              ]),
              const SizedBox(height: 10),
              _LangPicker(value: s.code, onChanged: onSetUiLanguage),
              const Divider(height: 28),
              Row(children: [
                const Icon(Icons.description_outlined, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text(s.t('report_language'), style: text.titleMedium)),
              ]),
              const SizedBox(height: 10),
              _LangPicker(value: reportLanguage, onChanged: onSetReportLanguage),
              const SizedBox(height: 8),
              Text(s.t('report_language_hint'), style: text.bodySmall),
            ]),
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

class _LangPicker extends StatelessWidget {
  const _LangPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'ar', label: Text('العربية')),
          ButtonSegment(value: 'fr', label: Text('Français')),
        ],
        selected: {value},
        onSelectionChanged: (v) => onChanged(v.first),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: text.bodySmall),
      const SizedBox(height: 2),
      Text(value, style: text.titleMedium),
    ]);
  }
}
