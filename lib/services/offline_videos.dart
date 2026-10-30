import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// "Add to Offline" in the video menu: the video file is downloaded once and
/// kept on this phone (up to 30 videos, for a year), so it plays without a
/// connection. The player uses the saved copy when there is one.
class OfflineVideos {
  OfflineVideos._();

  static final CacheManager _cache = CacheManager(
    Config(
      'offline_videos',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 30,
    ),
  );

  /// The saved copy of [url], or null.
  static Future<File?> find(String url) async {
    try {
      final info = await _cache.getFileFromCache(url);
      final file = info?.file;
      if (file != null && await file.exists()) return file;
    } catch (_) {}
    return null;
  }

  static Future<bool> isSaved(String url) async => (await find(url)) != null;

  /// Downloads the video (nothing happens when it is already saved).
  static Future<void> save(String url) async {
    await _cache.getSingleFile(url);
  }

  static Future<void> remove(String url) => _cache.removeFile(url);
}
