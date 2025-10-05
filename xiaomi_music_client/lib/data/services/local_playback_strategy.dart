import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playing_music.dart';
import '../models/music.dart';
import 'music_api_service.dart';
import 'playback_strategy.dart';
import 'audio_handler_service.dart';

/// 本地播放策略实现
/// 使用 just_audio 在手机本地播放音乐
class LocalPlaybackStrategy implements PlaybackStrategy {
  final MusicApiService _apiService;
  final AudioPlayer _player = AudioPlayer();
  AudioHandlerService? _audioHandler;

  // SharedPreferences 缓存 key（与 PlaybackProvider 保持一致）
  static const String _cacheKeyUrl = 'local_playback_url';
  static const String _cacheKeyName = 'local_playback_current_name';

  // 播放列表
  List<Music> _playlist = [];
  int _currentIndex = 0;
  String? _currentMusicName;
  String? _currentMusicUrl;
  String? _currentAlbumCover; // 当前封面图

  String? get currentMusicName => _currentMusicName;
  String? get currentMusicUrl => _currentMusicUrl;

  // 状态流控制器
  final _statusController = StreamController<PlayingMusic>.broadcast();

  // 上一首/下一首回调
  Function()? onNext;
  Function()? onPrevious;

  LocalPlaybackStrategy({required MusicApiService apiService})
    : _apiService = apiService {
    _initAudioSession();
    _initAudioService();
    _initPlayer();
    _loadCache(); // 🔧 启动时加载缓存
  }

  /// 初始化 AudioSession（配置音频焦点）
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      debugPrint('✅ [LocalPlayback] AudioSession 初始化成功');
    } catch (e) {
      debugPrint('❌ [LocalPlayback] AudioSession 初始化失败: $e');
    }
  }

  /// 初始化 AudioService
  Future<void> _initAudioService() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => AudioHandlerService(player: _player),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.xiaomi.music.channel.audio',
          androidNotificationChannelName: '小爱音乐盒',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: true,
        ),
      );
      debugPrint('✅ [LocalPlayback] AudioService 初始化成功');
    } catch (e) {
      debugPrint('❌ [LocalPlayback] AudioService 初始化失败: $e');
    }
  }

  void _initPlayer() {
    // 监听播放状态变化
    _player.playerStateStream.listen((state) {
      debugPrint(
        '🎵 [LocalPlayback] 播放器状态变化: playing=${state.playing}, processingState=${state.processingState}',
      );

      // 状态变化时立即更新UI
      _emitCurrentStatus();

      // 自动播放下一首
      if (state.processingState == ProcessingState.completed) {
        debugPrint('🎵 [LocalPlayback] 当前歌曲播放完成，尝试播放下一首');
        next();
      }
    });

    // 监听位置变化（用于更新进度）
    int lastEmittedSecond = -1;
    _player.positionStream.listen((position) {
      final currentSecond = position.inSeconds;
      // 每秒更新一次状态，避免重复更新
      if (currentSecond != lastEmittedSecond) {
        lastEmittedSecond = currentSecond;
        _emitCurrentStatus();
      }
    });
  }

  @override
  bool get isLocalMode => true;

  @override
  Future<void> play() async {
    debugPrint('🎵 [LocalPlayback] 执行播放');
    try {
      final ps = _player.playerState;
      debugPrint('🎵 [LocalPlayback] 当前播放器状态: ${ps.processingState}, playing: ${ps.playing}');

      if (ps.processingState == ProcessingState.idle) {
        // 🔧 如果播放器是 idle，尝试从缓存恢复
        if (_currentMusicUrl == null || _currentMusicUrl!.isEmpty) {
          await _loadCache();
        }

        if (_currentMusicUrl != null && _currentMusicUrl!.isNotEmpty) {
          debugPrint('🎵 [LocalPlayback] idle -> 先setUrl再play, URL: $_currentMusicUrl');
          await _player.setUrl(_currentMusicUrl!);
        } else {
          debugPrint('⚠️ [LocalPlayback] 无可用URL，忽略play');
          return;
        }
      }

      // 确保播放器已准备就绪
      debugPrint('🎵 [LocalPlayback] 开始播放，当前进度: ${_player.position.inSeconds}s');
      await _player.play();

      // 立即发射状态，确保UI更新
      _emitCurrentStatus();
      debugPrint('✅ [LocalPlayback] 播放成功，播放器状态: ${_player.playing}');
    } catch (e) {
      debugPrint('❌ [LocalPlayback] play失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    debugPrint('🎵 [LocalPlayback] 执行暂停');
    await _player.pause();
    _emitCurrentStatus();
  }

  @override
  Future<void> next() async {
    debugPrint('🎵 [LocalPlayback] 播放下一首');
    if (_playlist.isEmpty) {
      debugPrint('⚠️ [LocalPlayback] 播放列表为空');
      return;
    }

    _currentIndex = (_currentIndex + 1) % _playlist.length;
    final nextMusic = _playlist[_currentIndex];
    await playMusic(musicName: nextMusic.name);
  }

  @override
  Future<void> previous() async {
    debugPrint('🎵 [LocalPlayback] 播放上一首');
    if (_playlist.isEmpty) {
      debugPrint('⚠️ [LocalPlayback] 播放列表为空');
      return;
    }

    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    final prevMusic = _playlist[_currentIndex];
    await playMusic(musicName: prevMusic.name);
  }

  @override
  Future<void> seekTo(int seconds) async {
    debugPrint('🎵 [LocalPlayback] 跳转到 $seconds 秒');
    await _player.seek(Duration(seconds: seconds));
    _emitCurrentStatus();
  }

  @override
  Future<void> setVolume(int volume) async {
    debugPrint('🎵 [LocalPlayback] 设置音量: $volume');
    // 音量范围 0-100 转换为 0.0-1.0
    final normalizedVolume = volume / 100.0;
    await _player.setVolume(normalizedVolume.clamp(0.0, 1.0));
  }

  @override
  Future<void> playMusic({
    required String musicName,
    String? url,
    String? platform,
    String? songId,
  }) async {
    try {
      debugPrint('🎵 [LocalPlayback] 播放音乐: $musicName');
      debugPrint('🎵 [LocalPlayback] URL: $url');

      String playUrl = url ?? '';

      // 如果没有提供 URL，说明是服务器本地音乐，需要获取下载链接
      if (playUrl.isEmpty) {
        debugPrint('🎵 [LocalPlayback] 从服务器获取音乐链接: $musicName');
        final musicInfo = await _apiService.getMusicInfo(musicName);
        playUrl = musicInfo['url']?.toString() ?? '';

        if (playUrl.isEmpty) {
          throw Exception('无法获取音乐播放链接');
        }
        debugPrint('🎵 [LocalPlayback] 获取到播放链接: $playUrl');
      }

      // 使用 just_audio 播放
      _currentMusicName = musicName;
      _currentMusicUrl = playUrl;

      // 🔧 立即保存到缓存
      await _saveCache();

      await _player.setUrl(playUrl);
      await _player.play();

      // 🎵 更新媒体通知信息
      await _updateMediaNotification(
        title: musicName,
        artist: platform ?? '未知艺术家',
        album: '本地播放',
      );

      debugPrint('✅ [LocalPlayback] 开始播放: $musicName');
      _emitCurrentStatus();
    } catch (e) {
      debugPrint('❌ [LocalPlayback] 播放失败: $e');
      rethrow;
    }
  }

  /// 更新媒体通知信息
  Future<void> _updateMediaNotification({
    required String title,
    String? artist,
    String? album,
  }) async {
    if (_audioHandler == null) return;

    await _audioHandler!.setMediaItem(
      title: title,
      artist: artist,
      album: album,
      artUri: _currentAlbumCover,
      duration: _player.duration,
    );
  }

  /// 设置封面图（由 PlaybackProvider 调用）
  void setAlbumCover(String? coverUrl) {
    _currentAlbumCover = coverUrl;
    if (_currentMusicName != null) {
      _updateMediaNotification(
        title: _currentMusicName!,
        artist: '未知艺术家',
        album: '本地播放',
      );
    }
  }

  @override
  Future<void> playMusicList({
    required String listName,
    required String musicName,
  }) async {
    debugPrint('🎵 [LocalPlayback] 播放列表: $listName, 歌曲: $musicName');

    // 这里可以扩展为加载整个播放列表
    // 暂时只播放指定的歌曲
    await playMusic(musicName: musicName);
  }

  @override
  Future<PlayingMusic?> getCurrentStatus() async {
    if (_currentMusicName == null) {
      return null;
    }

    final position = _player.position;
    final duration = _player.duration;
    final isPlaying = _player.playing;

    return PlayingMusic(
      ret: '0', // ret 是 String 类型
      curMusic: _currentMusicName!, // 确保非空
      curPlaylist: '本地播放',
      isPlaying: isPlaying,
      offset: position.inSeconds,
      duration: duration?.inSeconds ?? 0,
    );
  }

  @override
  Future<int> getVolume() async {
    // 返回 0-100 的音量值
    final volume = _player.volume;
    return (volume * 100).round();
  }

  Future<void> prepareFromCache({required String url, String? name, int offset = 0}) async {
    try {
      debugPrint('🔧 [LocalPlayback] 从缓存预加载: $name, offset: $offset, URL: $url');

      // 直接使用传入的 URL 和 name
      _currentMusicUrl = url;
      if (name != null && name.isNotEmpty) {
        _currentMusicName = name;
      }

      // 保存到持久化缓存
      await _saveCache();

      // 设置播放器
      await _player.setUrl(url);
      if (offset > 0) {
        await _player.seek(Duration(seconds: offset));
      }

      // 立即发送状态更新，确保UI获取到正确的播放器状态
      _emitCurrentStatus();
      debugPrint('✅ [LocalPlayback] 预加载完成，播放器状态: ${_player.playing}, 进度: ${_player.position.inSeconds}/${_player.duration?.inSeconds ?? 0}');
    } catch (e) {
      debugPrint('❌ [LocalPlayback] 预加载失败: $e');
    }
  }

  @override
  Future<void> dispose() async {
    debugPrint('🎵 [LocalPlayback] 释放播放器资源');
    await _player.stop();
    await _player.dispose();
    await _statusController.close();
    await _audioHandler?.stop();
  }

  /// 发射当前播放状态到流
  void _emitCurrentStatus() {
    getCurrentStatus().then((status) {
      if (status != null && !_statusController.isClosed) {
        _statusController.add(status);
      }
    });
  }

  /// 设置播放列表
  void setPlaylist(List<Music> playlist, {int startIndex = 0}) {
    _playlist = playlist;
    _currentIndex = startIndex;
    debugPrint('🎵 [LocalPlayback] 设置播放列表: ${playlist.length} 首歌曲');
  }

  /// 获取当前播放列表
  List<Music> get playlist => List.unmodifiable(_playlist);

  /// 获取状态流
  Stream<PlayingMusic> get statusStream => _statusController.stream;

  /// 🔧 从缓存加载当前播放的 URL 和歌曲名
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentMusicUrl = prefs.getString(_cacheKeyUrl);
      _currentMusicName = prefs.getString(_cacheKeyName);

      debugPrint('🔧 [LocalPlayback] 从缓存加载:');
      debugPrint('   - 歌曲名: ${_currentMusicName ?? "null"}');
      debugPrint('   - URL: ${_currentMusicUrl ?? "null"}');
    } catch (e) {
      debugPrint('❌ [LocalPlayback] 加载缓存失败: $e');
    }
  }

  /// 🔧 保存当前播放的 URL 和歌曲名到缓存
  Future<void> _saveCache() async {
    try {
      if (_currentMusicUrl == null || _currentMusicUrl!.isEmpty) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyUrl, _currentMusicUrl!);
      if (_currentMusicName != null) {
        await prefs.setString(_cacheKeyName, _currentMusicName!);
      }

      debugPrint('💾 [LocalPlayback] 已保存缓存:');
      debugPrint('   - 歌曲名: $_currentMusicName');
      debugPrint('   - URL: $_currentMusicUrl');
    } catch (e) {
      debugPrint('❌ [LocalPlayback] 保存缓存失败: $e');
    }
  }
}
