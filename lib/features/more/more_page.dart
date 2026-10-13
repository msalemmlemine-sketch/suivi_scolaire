import 'package:flutter/material.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.s, required this.designer, required this.version, required this.onToggleLanguage, required this.onOpenFollowup});
  final S s;
  final String designer, version;
  final VoidCallback onToggleLanguage;
  final VoidCallback onOpenFollowup;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(child: InkWell(
          borderRadius: BorderRadius.circular(18), onTap: onOpenFollowup,
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const _IconBox(icon: Icons.fact_check_outlined), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('followup'), style: text.titleMedium), const SizedBox(height: 4),
              Text(s.t('followup_menu_hint'), style: text.bodySmall),
            ])), const SizedBox(width: 8), const Icon(Icons.chevron_right, color: AppColors.muted),
          ])),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const _IconBox(icon: Icons.translate), const SizedBox(width: 12), Expanded(child: Text(s.t('language'), style: text.titleMedium))]),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Text(s.t('language_value'), style: text.bodyLarge)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onToggleLanguage, icon: const Icon(Icons.swap_horiz), label: Text(s.t('switch_language'), maxLines: 2, textAlign: TextAlign.center))),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('about'), style: text.titleMedium), const SizedBox(height: 16),
          _InfoRow(label: s.t('designed_by'), value: designer),
          const Divider(height: 24),
          _InfoRow(label: s.t('version'), value: version),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.tealSoft.withValues(alpha: .55), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.offline_pin_outlined, color: AppColors.teal), const SizedBox(width: 10), Expanded(child: Text(s.t('offline_note'), style: text.bodySmall))])),
        ]))),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.teal));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 5),
    SelectableText(value, style: Theme.of(context).textTheme.titleMedium),
  ]);
}
