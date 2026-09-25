import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/storage_scanner.dart';
import 'app_controller.dart';

enum StorageCategory { junk, emptyFolders, largeFiles, documents }

enum CleanerState { checking, needsAccess, scanning, ready, error }

/// Storage cleanup (Android only): all-files access, scanning, deletion.
class StorageCleaner extends ChangeNotifier {
  StorageCleaner(this.app);

  final AppController app;
  static const root = '/storage/emulated/0';
  static const _scanner = StorageScanner();

  CleanerState state = CleanerState.checking;
  ScanResult? result;
  Duration? scanTook;
  bool _busy = false;

  static bool get supported => Platform.isAndroid;

  /// Android 11+ has a dedicated "All files access" switch; older versions
  /// use the classic storage permission.
  Future<Permission> _permission() async {
    final sdk = int.tryParse(await PhotoManager.systemVersion()) ?? 30;
    return sdk >= 30 ? Permission.manageExternalStorage : Permission.storage;
  }

  Future<bool> hasAccess() async => (await _permission()).isGranted;

  /// Check access, scanning straight away if it's there.
  Future<void> start() async {
    if (await hasAccess()) {
      await scan();
    } else {
      _set(CleanerState.needsAccess);
    }
  }

  /// Opens the system screen for the permission. The result arrives when the
  /// user comes back, so callers re-check with [start] on resume.
  Future<void> requestAccess() async {
    final granted = (await (await _permission()).request()).isGranted;
    if (granted) await scan();
  }

  Future<void> scan() async {
    if (_busy) return;
    _busy = true;
    _set(CleanerState.scanning);
    final watch = Stopwatch()..start();
    try {
      result = await _scanner.scanInBackground(root);
      scanTook = watch.elapsed;
      _set(CleanerState.ready);
    } catch (e) {
      debugPrint('Storage scan failed: $e');
      _set(CleanerState.error);
    } finally {
      _busy = false;
    }
  }

  List<FoundFile> filesIn(StorageCategory c) => switch (c) {
    StorageCategory.junk => result?.junk ?? const [],
    StorageCategory.largeFiles => result?.largeFiles ?? const [],
    StorageCategory.documents => result?.documents ?? const [],
    StorageCategory.emptyFolders => const [],
  };

  List<String> get emptyFolders => result?.emptyFolders ?? const [];

  int countIn(StorageCategory c) => c == StorageCategory.emptyFolders
      ? emptyFolders.length
      : filesIn(c).length;

  int bytesIn(StorageCategory c) =>
      filesIn(c).fold(0, (sum, f) => sum + f.size);

  /// Permanently deletes, then drops what's gone from every list.
  Future<DeleteReport> delete({
    List<FoundFile> files = const [],
    List<String> folders = const [],
  }) async {
    final report = await deletePermanently(files: files, folders: folders);
    final r = result;
    if (r != null && report.deleted.isNotEmpty) {
      bool gone(FoundFile f) => report.deleted.contains(f.path);
      r.junk.removeWhere(gone);
      r.largeFiles.removeWhere(gone);
      r.documents.removeWhere(gone);
      r.emptyFolders.removeWhere(report.deleted.contains);
      notifyListeners();
    }
    if (report.bytes > 0) {
      // Counts toward "Freed" on home; the "Deleted" stat stays photos only.
      await app.store.addFreed(bytes: report.bytes, count: 0);
    }
    if (report.deleted.isNotEmpty) {
      // Drop media-index rows for files that no longer exist, then refresh
      // the gallery in case photos or videos were among them.
      try {
        await PhotoManager.editor.android.removeAllNoExistsAsset();
      } catch (e) {
        debugPrint('Media index cleanup failed: $e');
      }
      await app.load(quiet: true);
    }
    return report;
  }

  void _set(CleanerState s) {
    state = s;
    notifyListeners();
  }
}
