import 'dart:async';
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
  static const _scanner = StorageScanner();

  CleanerState state = CleanerState.checking;
  ScanResult? result;
  Duration? scanTook;

  /// Whether access is the Android 11+ "All files access" switch in system
  /// Settings, rather than an ordinary permission prompt (Android 10-).
  bool usesAllFilesAccess = true;

  /// True while a delete is running, so the UI can stop a second one.
  bool deleting = false;
  bool _scanning = false;
  bool _disposed = false;

  static bool get supported => Platform.isAndroid;

  /// The current user's shared storage. `/storage/self/primary` points at
  /// it for whichever user is running the app (a work profile or second
  /// user is not `/storage/emulated/0`).
  static String resolveRoot() {
    try {
      final resolved = Directory('/storage/self/primary')
          .resolveSymbolicLinksSync();
      if (Directory(resolved).existsSync()) return resolved;
    } catch (_) {
      // Fall through to the usual location.
    }
    return '/storage/emulated/0';
  }

  Future<int> _sdk() async =>
      int.tryParse(await PhotoManager.systemVersion()) ?? 30;

  /// Android 11+ has a dedicated "All files access" switch; older versions
  /// use the classic storage permission.
  Future<Permission> _permission() async => await _sdk() >= 30
      ? Permission.manageExternalStorage
      : Permission.storage;

  Future<bool> hasAccess() async => (await _permission()).isGranted;

  /// Check access, scanning straight away if it's there.
  Future<void> start() async {
    usesAllFilesAccess = await _sdk() >= 30;
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
    if (_scanning || deleting) return;
    _scanning = true;
    _set(CleanerState.scanning);
    final watch = Stopwatch()..start();
    try {
      result = await _scanner.scanInBackground(resolveRoot());
      scanTook = watch.elapsed;
      _set(CleanerState.ready);
    } catch (e) {
      debugPrint('Storage scan failed: $e');
      _set(CleanerState.error);
    } finally {
      _scanning = false;
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

  /// Permanently deletes, drops what's gone from every list, and adds the
  /// space to the lifetime "Freed" total.
  Future<DeleteReport> delete({
    List<FoundFile> files = const [],
    List<String> folders = const [],
  }) async {
    if (deleting) {
      return const DeleteReport(deleted: {}, failed: 0, bytes: 0);
    }
    deleting = true;
    _notify();
    try {
      final report = await deletePermanently(files: files, folders: folders);
      final r = result;
      if (r != null && report.deleted.isNotEmpty) {
        bool gone(FoundFile f) => report.deleted.contains(f.path);
        r.junk.removeWhere(gone);
        r.largeFiles.removeWhere(gone);
        r.documents.removeWhere(gone);
        r.emptyFolders.removeWhere(report.deleted.contains);
      }
      // Counts toward "Freed" on home straight away; the "Deleted" stat
      // stays photos and videos only.
      await app.recordFreed(bytes: await _newlyFreed(files, report));
      if (report.deleted.isNotEmpty) unawaited(_syncGallery());
      return report;
    } finally {
      deleting = false;
      _notify();
    }
  }

  /// Bytes in [report] that have not been counted as freed before. Files
  /// this app itself sent to the system trash were counted then, so removing
  /// their leftovers now must not count them twice.
  Future<int> _newlyFreed(List<FoundFile> files, DeleteReport report) async {
    final leftovers = [
      for (final f in files)
        if (f.junk == JunkKind.trashLeftover && report.deleted.contains(f.path))
          f,
    ];
    final names = [for (final f in leftovers) trashedOriginalName(f.name)];
    final ours = await app.store.takeTrashed([for (final n in names) n ?? '']);
    var alreadyCounted = 0;
    for (var i = 0; i < leftovers.length; i++) {
      if (names[i] != null && ours[i]) alreadyCounted += leftovers[i].size;
    }
    return report.bytes - alreadyCounted;
  }

  /// Brings the photo library back in step after files were deleted from
  /// under it. Runs in the background: nothing on screen waits for it.
  Future<void> _syncGallery() async {
    try {
      // From Android 11 the system drops a file's media-index row when the
      // file is deleted. Older versions leave it behind, so sweep there
      // (slow: it checks every media file on the device).
      if (await _sdk() < 30) {
        await PhotoManager.editor.android.removeAllNoExistsAsset();
      }
    } catch (e) {
      debugPrint('Media index cleanup failed: $e');
    }
    await app.refreshAfterFileChanges();
  }

  void _set(CleanerState s) {
    state = s;
    _notify();
  }

  /// A scan or delete can finish after the screen is closed.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
