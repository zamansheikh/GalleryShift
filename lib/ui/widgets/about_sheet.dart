import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import 'common.dart';

abstract final class Developer {
  static const name = 'Zaman Sheikh';
  static const github = 'github.com/zamansheikh';
  static const facebook = 'fb.com/zamansheikh.404';
}

/// Opens [url] in the browser or the matching app. The app itself makes no
/// network requests; this hands the link to the system.
Future<void> _open(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse('https://$url'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Couldn’t open $url')));
  }
}

Future<void> showAboutSheet(BuildContext context) {
  final p = Palette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: p.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/brand/logo.png',
                width: 76,
                height: 76,
              ),
            ),
            const SizedBox(height: 14),
            Text('GalleryShift', style: AppText.title(color: p.text)),
            const SizedBox(height: 4),
            Text(
              'Swipe your gallery clean.',
              style: AppText.label(color: p.textDim),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'DESIGNED & DEVELOPED BY',
                    style: AppText.overline(color: p.textFaint),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Developer.name,
                    style: AppText.headline(color: p.text)
                        .copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LinkButton(
                          icon: Icons.code_rounded,
                          label: 'GitHub',
                          detail: Developer.github,
                          onTap: () => _open(context, Developer.github),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LinkButton(
                          icon: Icons.facebook_rounded,
                          label: 'Facebook',
                          detail: Developer.facebook,
                          onTap: () => _open(context, Developer.facebook),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 14, color: p.textFaint),
                const SizedBox(width: 6),
                Text(
                  'Your photos never leave your phone.',
                  style: AppText.caption(color: p.textFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: '$label: $detail',
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          children: [
            Icon(icon, color: p.accent, size: 22),
            const SizedBox(height: 6),
            Text(label, style: AppText.label(color: p.text)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                detail,
                style: AppText.w(11, FontWeight.w500, color: p.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
