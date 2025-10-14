import 'package:flutter/foundation.dart';
import '../models/lyric.dart';
import 'lyric_parser_service.dart';
import 'music_api_service.dart';
import 'native_music_search_service.dart';

/// 歌词服务
/// 负责获取和解析歌词
class LyricService {
  final MusicApiService _musicApi;
  final NativeMusicSearchService _nativeSearch;
  final LyricParserService _parser = LyricParserService();

  LyricService({
    required MusicApiService musicApi,
    required NativeMusicSearchService nativeSearch,
  })  : _musicApi = musicApi,
        _nativeSearch = nativeSearch;

  /// 获取歌词
  ///
  /// 优先从服务器获取,如果没有则从在线音乐平台刮削
  ///
  /// [musicName] 歌曲名称
  /// [autoScrape] 如果服务器没有歌词,是否自动从在线平台刮削
  Future<Lyric> getLyrics({
    required String musicName,
    bool autoScrape = true,
  }) async {
    try {
      debugPrint('🎤 [Lyric] 获取歌词: $musicName');

      // 1. 先从服务器获取
      final serverLyrics = await _getLyricsFromServer(musicName);
      if (serverLyrics != null && serverLyrics.hasLyrics) {
        debugPrint('✅ [Lyric] 从服务器获取到歌词');
        return serverLyrics;
      }

      // 2. 如果没有且允许刮削,从在线平台获取
      if (!autoScrape) {
        debugPrint('⚠️ [Lyric] 服务器无歌词,跳过刮削');
        return Lyric.empty();
      }

      debugPrint('🔍 [Lyric] 服务器无歌词,开始在线刮削...');
      final scrapedLyrics = await _scrapeLyricsFromOnline(musicName);

      if (scrapedLyrics != null && scrapedLyrics.hasLyrics) {
        debugPrint('✅ [Lyric] 刮削成功,后台上传到服务器');
        // 后台异步上传到服务器
        _uploadLyricsToServerAsync(musicName, scrapedLyrics);
        return scrapedLyrics;
      }

      debugPrint('⚠️ [Lyric] 刮削失败,无歌词');
      return Lyric.empty();
    } catch (e) {
      debugPrint('❌ [Lyric] 获取歌词失败: $e');
      return Lyric.empty();
    }
  }

  /// 从服务器获取歌词
  Future<Lyric?> _getLyricsFromServer(String musicName) async {
    try {
      final musicInfo = await _musicApi.getMusicInfo(musicName, includeTag: true);
      final lyricsText = musicInfo['tags']?['lyrics']?.toString();

      if (lyricsText != null && lyricsText.isNotEmpty) {
        debugPrint('✅ [Lyric] 服务器返回歌词,长度: ${lyricsText.length}');
        return _parser.parseLrc(lyricsText);
      }

      return null;
    } catch (e) {
      debugPrint('❌ [Lyric] 从服务器获取歌词失败: $e');
      return null;
    }
  }

  /// 从在线平台刮削歌词
  Future<Lyric?> _scrapeLyricsFromOnline(String musicName) async {
    try {
      // 解析歌曲名(格式:歌曲名 - 歌手名)
      final parts = musicName.split(' - ');
      final songName = parts.isNotEmpty ? parts[0].trim() : musicName;

      debugPrint('🔍 [Lyric] 搜索歌词: $songName');

      // 优先使用QQ音乐获取歌词(QQ音乐歌词质量最好)
      try {
        final results = await _nativeSearch.searchQQ(query: songName, page: 1);

        if (results.isEmpty) {
          debugPrint('⚠️ [Lyric] QQ音乐搜索无结果');
          return null;
        }

        // 找到第一个有songId的结果
        for (final result in results) {
          if (result.songId != null && result.songId!.isNotEmpty) {
            debugPrint('🎤 [Lyric] 获取歌词: ${result.title} - ${result.author}');

            final lyricsText = await _nativeSearch.getLyricsQQ(result.songId!);
            if (lyricsText != null && lyricsText.isNotEmpty) {
              debugPrint('✅ [Lyric] 获取到歌词,长度: ${lyricsText.length}');
              return _parser.parseLrc(lyricsText);
            }
          }
        }

        debugPrint('⚠️ [Lyric] 未找到可用歌词');
        return null;
      } catch (e) {
        debugPrint('❌ [Lyric] QQ音乐获取歌词失败: $e');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [Lyric] 刮削歌词失败: $e');
      return null;
    }
  }

  /// 后台异步上传歌词到服务器
  void _uploadLyricsToServerAsync(String musicName, Lyric lyric) {
    Future(() async {
      try {
        debugPrint('🔄 [Lyric] 后台上传歌词到服务器: $musicName');

        final lrcText = _parser.toLrc(lyric);
        await _musicApi.setMusicTag({
          'musicname': musicName,
          'lyrics': lrcText,
        });

        debugPrint('✅ [Lyric] 后台上传歌词成功');
      } catch (e) {
        debugPrint('❌ [Lyric] 后台上传歌词失败: $e');
        // 静默失败,不影响用户体验
      }
    });
  }
}
