import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../../data/storage_scanner.dart';
import '../../state/storage_cleaner.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/common.dart';
import 'storage_screen.dart';

extension on JunkKind {
  String get title => switch (this) {
    JunkKind.trashLeftover => 'Trash leftovers',
    JunkKind.installer => 'App installers (APK)',
    JunkKind.tempAndLogs => 'Temp files & logs',
    JunkKind.thumbnailCache => 'Thumbnail cache',
  };

  String get detail => switch (this) {
    JunkKind.trashLeftover => 'Hidden copies still taking space after deleting',
    JunkKind.installer => 'Usually already installed',
    JunkKind.tempAndLogs => 'Half-finished downloads, logs, OS litter',
    JunkKind.thumbnailCache => 'Rebuilt automatically when needed',
  };
}

/// One row in the flattened list: a section header or an entry.
sealed class _Row {}

class _Header extends _Row {
  _Header(this.kind, this.files);
  final JunkKind kind;
  final List<FoundFile> files;
}

class _FileRow extends _Row {
  _FileRow(this.file);
  final FoundFile file;
}

class _FolderRow extends _Row {
  _FolderRow(this.path);
  final String path;
}

class StorageCategoryScreen extends StatefulWidget {
  const StorageCategoryScreen({
    super.key,
    required this.cleaner,
    required this.category,
  });

  final StorageCleaner cleaner;
  final StorageCategory category;

  static Route<void> route(StorageCleaner cleaner, StorageCategory c) =>
      MaterialPageRoute(
        builder: (_) => StorageCategoryScreen(cleaner: cleaner, category: c),
      );

  @override
  State<StorageCategoryScreen> createState() => _StorageCategoryScreenState();
}

class _StorageCategoryScreenState extends State<StorageCategoryScreen> {
  final Set<String> _selected = {};
  bool _deleting = false;

  StorageCleaner get _c => widget.cleaner;
  StorageCategory get _cat => widget.category;

  /// Junk and empty folders are safe to clear, so they start selected;
  /// large files and documents need a deliberate pick.
  bool get _preselect =>
      _cat == StorageCategory.junk || _cat == StorageCategory.emptyFolders;

  List<FoundFile> get _files => _c.filesIn(_cat);
  List<String> get _folders =>
      _cat == StorageCategory.emptyFolders ? _c.emptyFolders : const [];

  Iterable<String> get _allPaths => _cat == StorageCategory.emptyFolders
      ? _folders
      : _files.map((f) => f.path);

  @override
  void initState() {
    super.initState();
    if (_preselect) _selected.addAll(_allPaths);
  }

  List<_Row> _rows() {
    if (_cat == StorageCategory.emptyFolders) {
      return [for (final f in _folders) _FolderRow(f)];
    }
    if (_cat != StorageCategory.junk) {
      return [for (final f in _files) _FileRow(f)];
    }
    final rows = <_Row>[];
    for (final kind in JunkKind.values) {
      final group = _files.where((f) => f.junk == kind).toList();
      if (group.isEmpty) continue;
      rows.add(_Header(kind, group));
      rows.addAll(group.map(_FileRow.new));
    }
    return rows;
  }

  void _toggle(String path) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(path)) _selected.add(path);
    });
  }

  void _toggleAll(Iterable<String> paths) {
    HapticFeedback.selectionClick();
    setState(() {
      final all = paths.every(_selected.contains);
      all ? _selected.removeAll(paths) : _selected.addAll(paths);
    });
  }

  Future<void> _open(FoundFile f) async {
    final result = await OpenFilex.open(f.path);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No app can open .${f.extension} files')),
      );
    }
  }

  Future<void> _delete() async {
    final files = _files.where((f) => _selected.contains(f.path)).toList();
    final folders = _folders.where(_selected.contains).toList();
    final bytes = files.fold<int>(0, (s, f) => s + f.size);
    final ok = await confirmPermanentDelete(
      context,
      title: 'Delete ${_cat.title.toLowerCase()}?',
      what: folders.isNotEmpty
          ? plural(folders.length, 'empty folder')
          : '${plural(files.length, 'file')} (${formatBytes(bytes)})',
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    HapticFeedback.mediumImpact();
    final report = await _c.delete(files: files, folders: folders);
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selected.removeAll(report.deleted);
    });
    showDeleteReport(context, report);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final rows = _rows();
        final present = _allPaths.toSet();
        _selected.retainAll(present);
        final selectedBytes = _files
            .where((f) => _selected.contains(f.path))
            .fold<int>(0, (s, f) => s + f.size);
        final color = _cat.color(p);

        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                                  _cat.title,
                                  style: AppText.title(color: p.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  present.isEmpty
                                      ? 'Nothing here'
                                      : _cat == StorageCategory.emptyFolders
                                      ? plural(present.length, 'folder')
                                      : '${plural(present.length, 'file')} · ${formatBytes(_c.bytesIn(_cat))}',
                                  style: AppText.caption(color: p.textDim),
                                ),
                              ],
                            ),
                          ),
                          if (present.isNotEmpty)
                            TextButton(
                              onPressed: () => _toggleAll(present),
                              child: Text(
                                present.every(_selected.contains)
                                    ? 'Select none'
                                    : 'Select all',
                                style: AppText.label(color: p.accent),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: present.isEmpty
                          ? _Empty(category: _cat)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                140,
                              ),
                              itemCount: rows.length,
                              itemBuilder: (context, i) => switch (rows[i]) {
                                _Header(:final kind, :final files) =>
                                  _GroupHeader(
                                    kind: kind,
                                    files: files,
                                    allSelected: files.every(
                                      (f) => _selected.contains(f.path),
                                    ),
                                    onToggle: () =>
                                        _toggleAll(files.map((f) => f.path)),
                                  ),
                                _FileRow(:final file) => _FileTile(
                                  file: file,
                                  root: _c.result!.root,
                                  selected: _selected.contains(file.path),
                                  accent: color,
                                  // Junk is cleared in bulk; the rest is
                                  // worth a look before deciding.
                                  onTap: _cat == StorageCategory.junk
                                      ? () => _toggle(file.path)
                                      : () => _open(file),
                                  onToggle: () => _toggle(file.path),
                                ),
                                _FolderRow(:final path) => _FolderTile(
                                  path: path,
                                  root: _c.result!.root,
                                  selected: _selected.contains(path),
                                  accent: color,
                                  onToggle: () => _toggle(path),
                                ),
                              },
                            ),
                    ),
                  ],
                ),
                if (present.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _DeleteBar(
                      count: _selected.length,
                      bytes: selectedBytes,
                      busy: _deleting,
                      onDelete: _selected.isEmpty ? null : _delete,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ tiles

String _relativeDir(String path, String root) {
  final dir = path.substring(0, path.lastIndexOf('/'));
  if (dir == root) return 'Internal storage';
  return dir.startsWith('$root/') ? dir.substring(root.length + 1) : dir;
}

(IconData, Color) _typeIcon(FoundFile f) => switch (f.extension) {
  'pdf' => (Icons.picture_as_pdf_rounded, const Color(0xFFFF5A5F)),
  'doc' ||
  'docx' ||
  'odt' ||
  'rtf' ||
  'pages' => (Icons.article_rounded, const Color(0xFF4D8DFF)),
  'xls' ||
  'xlsx' ||
  'ods' ||
  'csv' ||
  'numbers' => (Icons.table_chart_rounded, const Color(0xFF2FBF71)),
  'ppt' ||
  'pptx' ||
  'odp' ||
  'key' => (Icons.slideshow_rounded, const Color(0xFFFF8A3D)),
  'txt' || 'md' => (Icons.notes_rounded, const Color(0xFF9AA0B4)),
  'epub' || 'mobi' => (Icons.menu_book_rounded, const Color(0xFFB57BFF)),
  'mp4' ||
  'mkv' ||
  'mov' ||
  'avi' ||
  'webm' ||
  '3gp' => (Icons.movie_rounded, const Color(0xFFFF6BB5)),
  'jpg' ||
  'jpeg' ||
  'png' ||
  'heic' ||
  'webp' ||
  'gif' ||
  'dng' => (Icons.image_rounded, const Color(0xFF8B7BFF)),
  'mp3' ||
  'm4a' ||
  'wav' ||
  'flac' ||
  'aac' ||
  'ogg' ||
  'opus' => (Icons.audio_file_rounded, const Color(0xFF26C6DA)),
  'zip' ||
  'rar' ||
  '7z' ||
  'tar' ||
  'gz' => (Icons.folder_zip_rounded, const Color(0xFFFFB547)),
  'apk' ||
  'apks' ||
  'xapk' ||
  'apkm' => (Icons.android_rounded, const Color(0xFF3DDC84)),
  _ => (Icons.insert_drive_file_rounded, const Color(0xFF9AA0B4)),
};

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.root,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.onToggle,
  });

  final FoundFile file;
  final String root;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (icon, color) = _typeIcon(file);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: AppText.label(color: p.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_relativeDir(file.path, root)} · ${formatDate(file.modified)}',
                        style: AppText.caption(color: p.textDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatBytes(file.size),
                  style: AppText.label(color: p.textDim),
                ),
                _Check(selected: selected, color: accent, onTap: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.path,
    required this.root,
    required this.selected,
    required this.accent,
    required this.onToggle,
  });

  final String path;
  final String root;
  final bool selected;
  final Color accent;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rel = path.startsWith('$root/')
        ? path.substring(root.length + 1)
        : path;
    final name = rel.substring(rel.lastIndexOf('/') + 1);
    final parent = rel.contains('/')
        ? rel.substring(0, rel.lastIndexOf('/'))
        : 'Internal storage';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppText.label(color: p.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        parent,
                        style: AppText.caption(color: p.textDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _Check(selected: selected, color: accent, onTap: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.kind,
    required this.files,
    required this.allSelected,
    required this.onToggle,
  });

  final JunkKind kind;
  final List<FoundFile> files;
  final bool allSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bytes = files.fold<int>(0, (s, f) => s + f.size);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${kind.title} · ${formatBytes(bytes)}',
                  style: AppText.headline(color: p.text).copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(kind.detail, style: AppText.caption(color: p.textDim)),
              ],
            ),
          ),
          _Check(selected: allSelected, color: p.delete, onTap: onToggle),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: Motion.fast,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? color : p.textFaint,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({
    required this.count,
    required this.bytes,
    required this.busy,
    required this.onDelete,
  });

  final int count;
  final int bytes;
  final bool busy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bg.withValues(alpha: 0), p.bg, p.bg],
          stops: const [0, 0.3, 1],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        30,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: PrimaryButton(
        label: count == 0
            ? 'Select items to delete'
            : 'Delete ${formatCount(count)}${bytes > 0 ? ' · ${formatBytes(bytes)}' : ''}',
        icon: Icons.delete_rounded,
        color: p.delete,
        busy: busy,
        onTap: onDelete,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.category});
  final StorageCategory category;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: p.keep.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 44, color: p.keep),
            ),
            const SizedBox(height: 20),
            Text('All clear', style: AppText.title(color: p.text)),
            const SizedBox(height: 6),
            Text(
              'No ${category.title.toLowerCase()} found.',
              style: AppText.body(color: p.textDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
