import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Thin wrapper over photo_manager: permission, loading, sizes, deletion.
class GalleryRepository {
  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  final Map<String, int> _sizeCache = {};

  Future<PermissionState> permissionState() =>
      PhotoManager.getPermissionState(requestOption: _permissionOption);

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend(requestOption: _permissionOption);

  Future<void> openSettings() => PhotoManager.openSetting();

  Future<void> presentLimitedPicker() => PhotoManager.presentLimited();

  static bool hasAccess(PermissionState s) =>
      s == PermissionState.authorized || s == PermissionState.limited;

  FilterOptionGroup get _newestFirst => FilterOptionGroup(
    orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  /// Every photo and video in the library, newest first.
  Future<List<AssetEntity>> loadLibrary() async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
      filterOption: _newestFirst,
    );
    if (paths.isEmpty) return const [];
    final all = paths.first;
    final count = await all.assetCountAsync;
    const pageSize = 1500;
    final out = <AssetEntity>[];
    for (var start = 0; start < count; start += pageSize) {
      final end = start + pageSize > count ? count : start + pageSize;
      out.addAll(await all.getAssetListRange(start: start, end: end));
    }
    return out;
  }

  /// IDs of screenshots: the iOS smart album, or any Android album whose name
  /// contains "screenshot".
  Future<Set<String>> loadScreenshotIds() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: false,
    );
    final ids = <String>{};
    for (final path in paths) {
      final isScreenshots = Platform.isIOS
          ? path.albumTypeEx?.darwin?.subtype ==
                PMDarwinAssetCollectionSubtype.smartAlbumScreenshots
          : path.name.toLowerCase().contains('screenshot');
      if (!isScreenshots) continue;
      final count = await path.assetCountAsync;
      if (count == 0) continue;
      final assets = await path.getAssetListRange(start: 0, end: count);
      ids.addAll(assets.map((a) => a.id));
    }
    return ids;
  }

  int? cachedSize(String id) => _sizeCache[id];

  /// File size in bytes. Reads metadata only; never downloads from iCloud.
  Future<int> fileSize(AssetEntity asset) async {
    final cached = _sizeCache[asset.id];
    if (cached != null) return cached;
    try {
      final size = await asset.fileSize;
      _sizeCache[asset.id] = size;
      return size;
    } catch (e) {
      debugPrint('fileSize failed for ${asset.id}: $e');
      return 0;
    }
  }

  Future<int> totalSize(Iterable<AssetEntity> assets) async {
    final sizes = await Future.wait(assets.map(fileSize));
    return sizes.fold<int>(0, (a, b) => a + b);
  }

  /// Deletes via the system. Returns the IDs actually removed — empty if the
  /// user cancelled the system prompt.
  ///
  /// Android 11+ moves to the system trash (recoverable for 30 days); iOS
  /// moves to Recently Deleted.
  Future<List<String>> delete(List<AssetEntity> assets) async {
    if (assets.isEmpty) return const [];
    if (Platform.isAndroid && await _androidSdk() >= 30) {
      return PhotoManager.editor.android.moveToTrash(assets);
    }
    return PhotoManager.editor.deleteWithIds(assets.map((a) => a.id).toList());
  }

  int? _sdk;
  Future<int> _androidSdk() async {
    if (_sdk != null) return _sdk!;
    final version = await PhotoManager.systemVersion();
    // Android reports the SDK int as a string, e.g. "34".
    return _sdk = int.tryParse(version) ?? 0;
  }
}
