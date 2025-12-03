import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 媒体缓存服务
/// 用于缓存网络图片和视频，以 URL 为 key 进行缓存管理
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  Directory? _cacheDir;
  bool _initialized = false;

  /// 初始化缓存服务
  Future<void> init() async {
    if (_initialized) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/media_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('MediaCacheService init error: $e');
    }
  }

  /// 根据 URL 生成缓存文件名（包含分类前缀）
  String _getCacheFileName(String url, {CacheCategory? category}) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    final extension = _getFileExtension(url);
    final cat = category ?? _guessCategory(url);
    return '${cat.prefix}_${digest.toString()}$extension';
  }

  /// 根据 URL 猜测分类
  CacheCategory _guessCategory(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('avatar') || lowerUrl.contains('head')) {
      return CacheCategory.avatar;
    }
    if (lowerUrl.contains('product') || lowerUrl.contains('goods') || lowerUrl.contains('item')) {
      return CacheCategory.product;
    }
    if (lowerUrl.contains('post') || lowerUrl.contains('article') || lowerUrl.contains('content')) {
      return CacheCategory.post;
    }
    if (lowerUrl.contains('chat') || lowerUrl.contains('message')) {
      return CacheCategory.chat;
    }
    return CacheCategory.other;
  }

  /// 获取文件扩展名
  String _getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
      if (path.endsWith('.png')) return '.png';
      if (path.endsWith('.gif')) return '.gif';
      if (path.endsWith('.webp')) return '.webp';
      if (path.endsWith('.mp4')) return '.mp4';
      if (path.endsWith('.mov')) return '.mov';
      if (path.endsWith('.avi')) return '.avi';
      return '.cache';
    } catch (e) {
      return '.cache';
    }
  }


  /// 获取缓存文件路径
  Future<File?> getCacheFile(String url) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return null;

    final fileName = _getCacheFileName(url);
    final file = File('${_cacheDir!.path}/$fileName');
    
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// 检查是否已缓存
  Future<bool> isCached(String url) async {
    final file = await getCacheFile(url);
    return file != null;
  }

  /// 获取或下载媒体文件
  /// 如果已缓存则返回缓存文件，否则下载并缓存
  Future<File?> getOrDownload(String url) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return null;

    // 检查缓存
    final cachedFile = await getCacheFile(url);
    if (cachedFile != null) {
      debugPrint('MediaCache: Hit cache for $url');
      return cachedFile;
    }

    // 下载并缓存
    try {
      debugPrint('MediaCache: Downloading $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final fileName = _getCacheFileName(url);
        final file = File('${_cacheDir!.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('MediaCache: Cached $url');
        return file;
      }
    } catch (e) {
      debugPrint('MediaCache: Download error for $url: $e');
    }
    return null;
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    if (!_initialized) await init();
    if (_cacheDir == null) return 0;

    int totalSize = 0;
    try {
      if (await _cacheDir!.exists()) {
        await for (final entity in _cacheDir!.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('MediaCache: Get size error: $e');
    }
    return totalSize;
  }

  /// 格式化缓存大小显示
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 清除所有缓存
  Future<bool> clearCache() async {
    if (!_initialized) await init();
    if (_cacheDir == null) return false;

    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        debugPrint('MediaCache: Cache cleared');
        return true;
      }
    } catch (e) {
      debugPrint('MediaCache: Clear cache error: $e');
    }
    return false;
  }

  /// 获取缓存文件数量
  Future<int> getCacheFileCount() async {
    if (!_initialized) await init();
    if (_cacheDir == null) return 0;

    int count = 0;
    try {
      if (await _cacheDir!.exists()) {
        await for (final entity in _cacheDir!.list(recursive: true)) {
          if (entity is File) {
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('MediaCache: Get count error: $e');
    }
    return count;
  }

  /// 获取所有缓存文件信息
  Future<List<CacheFileInfo>> getCacheFiles() async {
    if (!_initialized) await init();
    if (_cacheDir == null) return [];

    final List<CacheFileInfo> files = [];
    try {
      if (await _cacheDir!.exists()) {
        await for (final entity in _cacheDir!.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            files.add(CacheFileInfo(
              file: entity,
              size: stat.size,
              modifiedTime: stat.modified,
            ));
          }
        }
      }
      // 按修改时间降序排序（最新的在前）
      files.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    } catch (e) {
      debugPrint('MediaCache: Get files error: $e');
    }
    return files;
  }

  /// 删除指定缓存文件
  Future<bool> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('MediaCache: Delete file error: $e');
    }
    return false;
  }

  /// 批量删除缓存文件
  Future<int> deleteFiles(List<File> files) async {
    int deletedCount = 0;
    for (final file in files) {
      if (await deleteFile(file)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }
}

/// 缓存分类
enum CacheCategory {
  avatar('avatar', '头像'),
  post('post', '帖子'),
  product('product', '闲置'),
  chat('chat', '聊天'),
  other('other', '其他');

  final String prefix;
  final String label;
  const CacheCategory(this.prefix, this.label);

  static CacheCategory fromFileName(String fileName) {
    if (fileName.startsWith('avatar_')) return CacheCategory.avatar;
    if (fileName.startsWith('post_')) return CacheCategory.post;
    if (fileName.startsWith('product_')) return CacheCategory.product;
    if (fileName.startsWith('chat_')) return CacheCategory.chat;
    return CacheCategory.other;
  }
}

/// 缓存文件信息
class CacheFileInfo {
  final File file;
  final int size;
  final DateTime modifiedTime;

  CacheFileInfo({
    required this.file,
    required this.size,
    required this.modifiedTime,
  });

  /// 获取文件名
  String get fileName => file.path.split('/').last;

  /// 获取分类
  CacheCategory get category => CacheCategory.fromFileName(fileName);

  /// 判断是否为图片
  bool get isImage {
    final ext = fileName.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp');
  }

  /// 判断是否为视频
  bool get isVideo {
    final ext = fileName.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi');
  }
}
