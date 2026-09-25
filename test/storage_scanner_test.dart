import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_shift/data/storage_scanner.dart';

void main() {
  late Directory root;

  File file(String rel, {int bytes = 10, DateTime? modified}) {
    final f = File('${root.path}/$rel')..createSync(recursive: true);
    f.writeAsBytesSync(List.filled(bytes, 0));
    if (modified != null) f.setLastModifiedSync(modified);
    return f;
  }

  Directory dir(String rel) =>
      Directory('${root.path}/$rel')..createSync(recursive: true);

  String rel(String path) => path.substring(root.path.length + 1);

  setUp(() => root = Directory.systemTemp.createTempSync('gs_scan_'));
  tearDown(() => root.deleteSync(recursive: true));

  const scanner = StorageScanner(largeFileBytes: 1000);

  test('classifies junk by kind', () {
    final old = DateTime.now().subtract(const Duration(days: 3));
    file('DCIM/Camera/.trashed-1790000000-IMG_1.jpg');
    file('Pictures/.pending-1790000000-new.jpg', modified: old);
    file('Pictures/.pending-1790000000-writing-now.jpg'); // fresh: in use
    file('Download/whatsapp.apk');
    file('Download/movie.mp4.crdownload');
    file('Documents/app.log');
    file('Documents/._resource');
    file('DCIM/.thumbnails/123.jpg');
    file('Pictures/photo.jpg'); // normal

    final r = scanner.scan(root.path);
    final kinds = {for (final f in r.junk) rel(f.path): f.junk};

    expect(kinds, {
      'DCIM/Camera/.trashed-1790000000-IMG_1.jpg': JunkKind.trashLeftover,
      'Pictures/.pending-1790000000-new.jpg': JunkKind.trashLeftover,
      'Download/whatsapp.apk': JunkKind.installer,
      'Download/movie.mp4.crdownload': JunkKind.tempAndLogs,
      'Documents/app.log': JunkKind.tempAndLogs,
      'Documents/._resource': JunkKind.tempAndLogs,
      'DCIM/.thumbnails/123.jpg': JunkKind.thumbnailCache,
    });
  });

  test('never treats system marker files as junk', () {
    file('Pictures/.thumbnails/.nomedia');
    file('Pictures/.thumbnails/.database_uuid');
    file('Pictures/.thumbnails/9.jpg');
    file('Download/.nomedia');

    final r = scanner.scan(root.path);
    expect(r.junk.map((f) => rel(f.path)), ['Pictures/.thumbnails/9.jpg']);
  });

  test('finds large files and documents, biggest first', () {
    file('Movies/big.mp4', bytes: 5000);
    file('Download/bigger.zip', bytes: 8000);
    file('Movies/small.mp4', bytes: 10);
    file('Documents/report.pdf', bytes: 300);
    file('Documents/notes.TXT', bytes: 200);
    file('Download/huge.docx', bytes: 2000); // large and a document

    final r = scanner.scan(root.path);
    expect(r.largeFiles.map((f) => rel(f.path)), [
      'Download/bigger.zip',
      'Movies/big.mp4',
      'Download/huge.docx',
    ]);
    expect(r.documents.map((f) => rel(f.path)), [
      'Download/huge.docx',
      'Documents/report.pdf',
      'Documents/notes.TXT',
    ]);
  });

  test('reports top-most empty folders only, never standard or hidden', () {
    dir('Old/Nested/Deeper'); // wholly empty: report Old only
    dir('Pictures/Empty'); // inside a standard folder: report it
    dir('Download/A/B'); // standard folder with only empty subfolders
    dir('Music'); // standard, empty: keep
    dir('.hidden'); // hidden: keep
    dir('Photos/Kept');
    file('Photos/keep.jpg');
    dir('Android/data/some.app/cache'); // never touched

    final r = scanner.scan(root.path);
    expect(r.emptyFolders.map(rel).toSet(), {
      'Old',
      'Pictures/Empty',
      'Download/A',
      'Photos/Kept',
    });
  });

  test('never scans inside Android/', () {
    file('Android/data/app/files/huge.bin', bytes: 5000);
    file('Android/obb/game.apk');
    final r = scanner.scan(root.path);
    expect(r.largeFiles, isEmpty);
    expect(r.junk, isEmpty);
  });

  test('deletePermanently removes files and still-empty folders', () async {
    file('Download/a.apk', bytes: 100);
    file('Download/b.log', bytes: 50);
    dir('Old/Empty');
    dir('Gained');

    final r = scanner.scan(root.path);
    // A file appears in "Gained" after the scan: it must survive.
    file('Gained/new.jpg');

    final report = await deletePermanently(
      files: r.junk,
      folders: r.emptyFolders,
    );

    expect(report.bytes, 150);
    expect(report.failed, 1); // "Gained" is no longer empty
    expect(File('${root.path}/Download/a.apk').existsSync(), isFalse);
    expect(Directory('${root.path}/Old').existsSync(), isFalse);
    expect(File('${root.path}/Gained/new.jpg').existsSync(), isTrue);
  });
}
