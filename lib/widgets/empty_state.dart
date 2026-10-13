import 'package:flutter/material.dart';

import '../app/theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body});
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.tealSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.teal),
            ),
            const SizedBox(height: 16),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body!, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
