import 'dart:io';
import 'dart:isolate';

/// Kinds of files that are safe to clear without looking at them one by one.
enum JunkKind {
  /// `.trashed-…` files Android's trash leaves behind, and abandoned
  /// `.pending-…` writes.
  trashLeftover,

  /// App installers (.apk) that have usually been installed already.
  installer,

  /// Temp files, logs, half-finished downloads, OS litter.
  tempAndLogs,

  /// Files in `.thumbnails` folders; the system rebuilds them.
  thumbnailCache,
}

class FoundFile {
  const FoundFile({
    required this.path,
    required this.size,
    required this.modified,
    this.junk,
  });

  final String path;
  final int size;
  final DateTime modified;
  final JunkKind? junk;

  String get name => path.substring(path.lastIndexOf('/') + 1);

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

class ScanResult {
  const ScanResult({
    required this.root,
    required this.junk,
    required this.emptyFolders,
    required this.largeFiles,
    required this.documents,
    required this.filesScanned,
  });

  final String root;
  final List<FoundFile> junk;

  /// Top-most folders that contain no files at any depth.
  final List<String> emptyFolders;

  /// Biggest first.
  final List<FoundFile> largeFiles;

  /// Biggest first.
  final List<FoundFile> documents;
  final int filesScanned;

  int get junkBytes => junk.fold(0, (s, f) => s + f.size);
}

/// Scans shared storage for junk, empty folders, large files and documents.
///
/// Never looks inside `Android/` (other apps' private data), and never
/// reports the standard top-level folders (DCIM, Download, …) as empty.
class StorageScanner {
  const StorageScanner({this.largeFileBytes = 50 * 1024 * 1024});

  final int largeFileBytes;

  static const _protectedTopLevel = {
    'android', 'alarms', 'audiobooks', 'dcim', 'documents', 'download', //
    'downloads', 'movies', 'music', 'notifications', 'pictures', 'podcasts',
    'recordings', 'ringtones',
  };

  static const _documentExt = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', //
    'odp', 'rtf', 'txt', 'csv', 'md', 'epub', 'mobi', 'pages', 'numbers',
    'key',
  };

  static const _installerExt = {'apk', 'apks', 'xapk', 'apkm'};

  static const _tempExt = {
    'tmp', 'temp', 'log', 'crdownload', 'part', 'partial', 'download', //
  };

  static const _osLitter = {'thumbs.db', '.ds_store', 'desktop.ini'};

  /// Marker files the system relies on. `.nomedia` keeps a folder out of the
  /// gallery; deleting it would make e.g. thumbnail caches show up as photos.
  static const _systemMarkers = {'.nomedia', '.database_uuid'};

  /// Runs [scan] on a background isolate.
  Future<ScanResult> scanInBackground(String root) {
    final limit = largeFileBytes;
    return Isolate.run(() => StorageScanner(largeFileBytes: limit).scan(root));
  }

  ScanResult scan(String root) {
    final junk = <FoundFile>[];
    final empty = <String>[];
    final large = <FoundFile>[];
    final docs = <FoundFile>[];
    var scanned = 0;
    final staleBefore = DateTime.now().subtract(const Duration(days: 1));

    void addFile(File f, {required bool inThumbnails}) {
      final FileStat stat;
      try {
        stat = f.statSync();
      } catch (_) {
        return;
      }
      scanned++;
      final found = FoundFile(
        path: f.path,
        size: stat.size,
        modified: stat.modified,
        junk: _junkKind(f.path, stat.modified, inThumbnails, staleBefore),
      );
      if (found.junk != null) {
        junk.add(found);
        return;
      }
      if (found.size >= largeFileBytes) large.add(found);
      if (_documentExt.contains(found.extension)) docs.add(found);
    }

    /// Returns true when [dir] holds no files at any depth.
    ///
    /// An [anchor] folder is never deleted itself (the root, and standard
    /// folders like DCIM), so its empty subfolders are always reported.
    bool visit(Directory dir, {required bool anchor, required bool inThumbs}) {
      final isRoot = dir.path == root;
      final List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } catch (_) {
        return false; // Unreadable: treat as in use.
      }
      var isEmpty = true;
      final emptyChildren = <String>[];
      for (final e in entries) {
        final name = e.path.substring(e.path.lastIndexOf('/') + 1);
        if (e is Directory) {
          if (isRoot && name.toLowerCase() == 'android') {
            isEmpty = false;
            continue;
          }
          final childEmpty = visit(
            e,
            anchor: isRoot && _protectedTopLevel.contains(name.toLowerCase()),
            inThumbs: inThumbs || name == '.thumbnails',
          );
          if (childEmpty) {
            if (_reportable(name, isRoot)) emptyChildren.add(e.path);
          } else {
            isEmpty = false;
          }
        } else if (e is File) {
          isEmpty = false;
          addFile(e, inThumbnails: inThumbs);
        } else {
          isEmpty = false; // Symlinks and the like: leave alone.
        }
      }
      // An empty folder is reported by its parent only if the parent itself
      // has content; otherwise the parent is reported instead.
      if (!isEmpty || anchor) empty.addAll(emptyChildren);
      return isEmpty;
    }

    visit(Directory(root), anchor: true, inThumbs: false);

    int bySize(FoundFile a, FoundFile b) => b.size.compareTo(a.size);
    large.sort(bySize);
    docs.sort(bySize);
    junk.sort(bySize);
    empty.sort();

    return ScanResult(
      root: root,
      junk: junk,
      emptyFolders: empty,
      largeFiles: large,
      documents: docs,
      filesScanned: scanned,
    );
  }

  bool _reportable(String name, bool isRoot) {
    if (name.startsWith('.')) return false; // Hidden: often an app's marker.
    if (isRoot && _protectedTopLevel.contains(name.toLowerCase())) {
      return false;
    }
    return true;
  }

  JunkKind? _junkKind(
    String path,
    DateTime modified,
    bool inThumbnails,
    DateTime staleBefore,
  ) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    final lower = name.toLowerCase();
    if (_systemMarkers.contains(lower)) return null;
    if (lower.startsWith('.trashed-')) return JunkKind.trashLeftover;
    if (lower.startsWith('.pending-') && modified.isBefore(staleBefore)) {
      return JunkKind.trashLeftover;
    }
    // Only the cached images themselves; hidden files there are the media
    // provider's bookkeeping.
    if (inThumbnails && !lower.startsWith('.')) return JunkKind.thumbnailCache;
    final dot = lower.lastIndexOf('.');
    final ext = dot <= 0 ? '' : lower.substring(dot + 1);
    if (_installerExt.contains(ext)) return JunkKind.installer;
    if (_tempExt.contains(ext) ||
        _osLitter.contains(lower) ||
        lower.startsWith('._')) {
      return JunkKind.tempAndLogs;
    }
    return null;
  }
}

class DeleteReport {
  const DeleteReport({
    required this.deleted,
    required this.failed,
    required this.bytes,
  });

  /// Paths actually removed.
  final Set<String> deleted;
  final int failed;
  final int bytes;
}

/// Permanently deletes [files] and [folders] on a background isolate.
///
/// Folders are removed only if they still contain no files, so a folder that
/// gained a file since the scan is left alone.
Future<DeleteReport> deletePermanently({
  required List<FoundFile> files,
  required List<String> folders,
}) {
  final filePaths = [for (final f in files) (f.path, f.size)];
  return Isolate.run(() {
    final deleted = <String>{};
    var failed = 0;
    var bytes = 0;
    for (final (path, size) in filePaths) {
      try {
        File(path).deleteSync();
        deleted.add(path);
        bytes += size;
      } catch (_) {
        failed++;
      }
    }
    for (final path in folders) {
      try {
        final dir = Directory(path);
        final stillEmpty = dir
            .listSync(recursive: true, followLinks: false)
            .every((e) => e is Directory);
        if (!stillEmpty) {
          failed++;
          continue;
        }
        dir.deleteSync(recursive: true);
        deleted.add(path);
      } catch (_) {
        failed++;
      }
    }
    return DeleteReport(deleted: deleted, failed: failed, bytes: bytes);
  });
}
