import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/storage_scanner.dart';
import '../../state/app_scope.dart';
import '../../state/storage_cleaner.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/common.dart';
import 'storage_category_screen.dart';

extension StorageCategoryUi on StorageCategory {
  String get title => switch (this) {
    StorageCategory.junk => 'Junk files',
    StorageCategory.emptyFolders => 'Empty folders',
    StorageCategory.largeFiles => 'Large files',
    StorageCategory.documents => 'Documents',
  };

  String get blurb => switch (this) {
    StorageCategory.junk =>
      'Trash leftovers, old installers, temp files and thumbnail caches.',
    StorageCategory.emptyFolders => 'Folders with nothing inside.',
    StorageCategory.largeFiles => 'Files over 50 MB, biggest first.',
    StorageCategory.documents => 'PDFs, Office files, text and ebooks.',
  };

  IconData get icon => switch (this) {
    StorageCategory.junk => Icons.delete_sweep_rounded,
    StorageCategory.emptyFolders => Icons.folder_off_rounded,
    StorageCategory.largeFiles => Icons.storage_rounded,
    StorageCategory.documents => Icons.description_rounded,
  };

  Color color(Palette p) => switch (this) {
    StorageCategory.junk => p.delete,
    StorageCategory.emptyFolders => const Color(0xFFFFB547),
    StorageCategory.largeFiles => p.accent,
    StorageCategory.documents => const Color(0xFF4DA3FF),
  };
}

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const StorageScreen());

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late final StorageCleaner _cleaner = StorageCleaner(AppScope.read(context));
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Access is granted in system Settings; pick it up when the user returns.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_cleaner.state == CleanerState.needsAccess) _cleaner.start();
      },
    );
    _cleaner.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _cleaner.dispose();
    super.dispose();
  }

  Future<void> _cleanJunk() async {
    final junk = _cleaner.filesIn(StorageCategory.junk);
    final folders = _cleaner.emptyFolders;
    final bytes = _cleaner.bytesIn(StorageCategory.junk);
    final ok = await confirmPermanentDelete(
      context,
      title: 'Clean junk?',
      what: [
        if (junk.isNotEmpty)
          '${plural(junk.length, 'junk file')} (${formatBytes(bytes)})',
        if (folders.isNotEmpty) plural(folders.length, 'empty folder'),
      ].join(' and '),
    );
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    final report = await _cleaner.delete(
      files: List.of(junk),
      folders: List.of(folders),
    );
    if (!mounted) return;
    showDeleteReport(context, report);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _cleaner,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storage cleanup',
                            style: AppText.title(color: p.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Junk, empty folders, large files & documents',
                            style: AppText.caption(color: p.textDim),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  child: switch (_cleaner.state) {
                    CleanerState.checking => const SizedBox.shrink(),
                    CleanerState.needsAccess => _AccessNeeded(
                      onAllow: _cleaner.requestAccess,
                    ),
                    CleanerState.scanning => const _Scanning(),
                    CleanerState.error => _ScanError(onRetry: _cleaner.scan),
                    CleanerState.ready => _Summary(
                      cleaner: _cleaner,
                      onCleanJunk: _cleanJunk,
                      onOpen: (c) =>
                          Navigator.of(context)
                              .push(StorageCategoryScreen.route(_cleaner, c)),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ states

class _AccessNeeded extends StatelessWidget {
  const _AccessNeeded({required this.onAllow});
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: p.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.4),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.cleaning_services_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Allow all files access',
            style: AppText.title(color: p.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'To find junk, empty folders, large files and documents, '
            'GalleryShift needs to look through your phone’s shared storage.',
            style: AppText.body(color: p.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          for (final (icon, text) in [
            (Icons.visibility_rounded, 'You review everything before it goes'),
            (
              Icons.lock_rounded,
              'Nothing is uploaded; it all stays on the phone',
            ),
            (Icons.shield_rounded, 'Other apps’ private data is never touched'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(text, style: AppText.label(color: p.text)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Open settings',
            icon: Icons.settings_rounded,
            onTap: onAllow,
          ),
          const SizedBox(height: 12),
          Text(
            'Turn on “Allow access to manage all files”, then come back.',
            style: AppText.caption(color: p.textFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Scanning extends StatefulWidget {
  const _Scanning();

  @override
  State<_Scanning> createState() => _ScanningState();
}

class _ScanningState extends State<_Scanning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _spin,
                  child: CustomPaint(
                    size: const Size.square(132),
                    painter: _ArcPainter(colors: [p.accent, p.accentAlt]),
                  ),
                ),
                Icon(Icons.search_rounded, size: 44, color: p.text),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Scanning storage…', style: AppText.title(color: p.text)),
          const SizedBox(height: 6),
          Text(
            'Looking through your folders',
            style: AppText.label(color: p.textDim),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.colors});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    canvas.drawArc(
      rect,
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [colors.first.withValues(alpha: 0), ...colors],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.colors != colors;
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 44, color: p.textFaint),
            const SizedBox(height: 14),
            Text('Scan failed', style: AppText.title(color: p.text)),
            const SizedBox(height: 20),
            SecondaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- summary

class _Summary extends StatelessWidget {
  const _Summary({
    required this.cleaner,
    required this.onCleanJunk,
    required this.onOpen,
  });

  final StorageCleaner cleaner;
  final VoidCallback onCleanJunk;
  final void Function(StorageCategory) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final junkBytes = cleaner.bytesIn(StorageCategory.junk);
    final junkCount = cleaner.countIn(StorageCategory.junk);
    final folders = cleaner.emptyFolders.length;
    final clean = junkCount == 0 && folders == 0;
    final r = cleaner.result!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: p.stroke),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(p.accent.withValues(alpha: 0.14), p.surface),
                p.surface,
                Color.alphaBlend(
                  p.accentAlt.withValues(alpha: 0.10),
                  p.surface,
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clean ? 'ALL CLEAN' : 'READY TO FREE',
                style: AppText.overline(color: p.textFaint),
              ),
              const SizedBox(height: 6),
              Text(
                clean ? 'Nothing to clean' : formatBytes(junkBytes),
                style: AppText.display(color: p.text),
              ),
              const SizedBox(height: 4),
              Text(
                clean
                    ? 'No junk files or empty folders found.'
                    : [
                        if (junkCount > 0) plural(junkCount, 'junk file'),
                        if (folders > 0) plural(folders, 'empty folder'),
                      ].join(' · '),
                style: AppText.label(color: p.textDim),
              ),
              if (!clean) ...[
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Clean junk',
                  icon: Icons.auto_awesome_rounded,
                  onTap: onCleanJunk,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'Review',
          style: AppText.title(color: p.text).copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        for (final c in StorageCategory.values) ...[
          _CategoryRow(
            category: c,
            count: cleaner.countIn(c),
            bytes: c == StorageCategory.emptyFolders
                ? null
                : cleaner.bytesIn(c),
            onTap: () => onOpen(c),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: cleaner.scan,
            icon: Icon(Icons.refresh_rounded, size: 18, color: p.textDim),
            label: Text(
              'Scanned ${formatCount(r.filesScanned)} files'
              '${_took(cleaner.scanTook)}'
              ' · Scan again',
              style: AppText.caption(color: p.textDim),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.count,
    required this.bytes,
    required this.onTap,
  });

  final StorageCategory category;
  final int count;
  final int? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = category.color(p);
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(category.icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: AppText.headline(color: p.text)
                        .copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    category.blurb,
                    style: AppText.caption(color: p.textDim),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCount(count),
                  style: AppText.headline(
                    color: count == 0 ? p.textFaint : p.text,
                  ),
                ),
                if (bytes != null && bytes! > 0)
                  Text(
                    formatBytes(bytes!),
                    style: AppText.caption(color: p.textDim),
                  ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: p.textFaint),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ shared bits

/// Confirms a permanent delete. [what] describes the items, e.g.
/// "12 junk files (40 MB)".
Future<bool> confirmPermanentDelete(
  BuildContext context, {
  required String title,
  required String what,
}) async {
  final p = Palette.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: AppText.title(color: p.text)),
      content: Text(
        '$what will be deleted permanently. They skip the trash and can’t be recovered.',
        style: AppText.body(color: p.textDim),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text('Cancel', style: AppText.label(color: p.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text('Delete', style: AppText.label(color: p.delete)),
        ),
      ],
    ),
  );
  return ok == true;
}

void showDeleteReport(BuildContext context, DeleteReport report) {
  final parts = <String>[
    if (report.bytes > 0)
      'Freed ${formatBytes(report.bytes)}'
    else
      'Deleted ${plural(report.deleted.length, 'item')}',
    if (report.failed > 0) '${formatCount(report.failed)} couldn’t be removed',
  ];
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(parts.join(' · '))));
}

String _took(Duration? d) {
  if (d == null) return '';
  if (d.inMilliseconds < 1000) return ' in under a second';
  return ' in ${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
}
