import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/playing_music.dart';
import '../models/music.dart';
import 'playback_strategy.dart';
import 'mi_iot_service.dart';
import 'audio_handler_service.dart';
import 'mi_hardware_detector.dart';
import 'mi_play_mode.dart';

/// 小米IoT直连播放策略
/// 不依赖xiaomusic服务端，直接调用小米云端API控制小爱音箱
/// 实现 PlaybackStrategy 接口，与现有架构完美集成
class MiIoTDirectPlaybackStrategy implements PlaybackStrategy {
  final MiIoTService _miService;
  final String _deviceId;
  final String _deviceName;
  AudioHandlerService? _audioHandler;

  // 状态变化回调
  Function()? onStatusChanged;

  // 获取音乐URL的回调（由PlaybackProvider设置）
  Future<String?> Function(String musicName)? onGetMusicUrl;

  // 当前播放状态缓存
  PlayingMusic? _currentPlayingMusic;
  String? _albumCoverUrl;

  // 🎵 播放列表管理（APP端维护）
  List<Music> _playlist = [];
  int _currentIndex = 0;

  // 🔄 状态轮询定时器
  Timer? _statusTimer;

  // 🎯 设备硬件信息
  String? _hardware;

  MiIoTDirectPlaybackStrategy({
    required MiIoTService miService,
    required String deviceId,
    String? deviceName,
    AudioHandlerService? audioHandler,
    Function()? onStatusChanged, // 🔧 在构造函数中接收回调，确保轮询启动前已设置
    Future<String?> Function(String musicName)? onGetMusicUrl, // 🔧 在构造函数中接收回调
  })  : _miService = miService,
        _deviceId = deviceId,
        _deviceName = deviceName ?? '小爱音箱',
        _audioHandler = audioHandler,
        onStatusChanged = onStatusChanged, // 🔧 立即设置回调，避免 NULL 问题
        onGetMusicUrl = onGetMusicUrl {    // 🔧 立即设置回调
    _initializeAudioHandler();
    _initializeHardwareInfo(); // 🎯 初始化硬件信息
    _startStatusPolling(); // 🔄 启动状态轮询
  }

  /// 🎯 初始化设备硬件信息
  Future<void> _initializeHardwareInfo() async {
    try {
      // 获取设备列表并找到当前设备
      final devices = await _miService.getDevices();
      final device = devices.firstWhere(
        (d) => d.deviceId == _deviceId || d.did == _deviceId,
        orElse: () => MiDevice(deviceId: '', did: '', name: '', hardware: ''),
      );

      if (device.hardware.isNotEmpty) {
        _hardware = device.hardware;
        final hardwareDesc = MiHardwareDetector.getHardwareDescription(_hardware!);
        final playMethod = MiHardwareDetector.getRecommendedPlayMethod(_hardware!);
        debugPrint('📱 [MiIoTDirect] 设备硬件: ${_hardware!} ($hardwareDesc)');
        debugPrint('🎵 [MiIoTDirect] 推荐播放方式: $playMethod');
      }
    } catch (e) {
      debugPrint('⚠️ [MiIoTDirect] 初始化硬件信息失败: $e');
    }
  }

  /// 🔄 启动状态轮询（每3秒获取一次播放状态）
  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollPlayStatus();
    });
    debugPrint('⏰ [MiIoTDirect] 启动状态轮询');
  }

  /// 🔄 轮询播放状态
  Future<void> _pollPlayStatus() async {
    try {
      final status = await _miService.getPlayStatus(_deviceId);
      if (status != null) {
        // 解析状态
        final isPlaying = status['status'] == 1;
        final detail = status['play_song_detail'] as Map<String, dynamic>?;

        debugPrint('🔄 [MiIoTDirect] 轮询状态: status=$isPlaying, detail=$detail');

        if (detail != null) {
          final title = detail['title'] as String?;
          final durationMs = detail['duration'] as int? ?? 0; // 毫秒
          final positionMs = detail['position'] as int? ?? 0; // 毫秒

          // 🎯 将毫秒转换为秒（与 xiaomusic 模式保持一致）
          final duration = (durationMs / 1000).round();
          final position = (positionMs / 1000).round();

          // 🎯 智能更新：只有当新值有效时才更新，否则保留原值
          // 注意：小米 IoT API 通常不返回 title，所以必须保留原来的歌曲名！
          String finalTitle;
          int finalDuration;

          // 🎯 智能状态更新策略
          // 关键原则：轮询只负责更新进度和播放状态，不修改歌曲名！
          // 歌曲名只能由 playMusic() 设置（因为 API 不返回）
          if (_currentPlayingMusic != null) {
            // 已有播放信息，智能合并
            // 🎯 优先使用 API 返回的 title（罕见），否则保留原歌曲名
            finalTitle = (title != null && title.isNotEmpty)
                ? title
                : _currentPlayingMusic!.curMusic; // 🔧 保留原歌曲名（无论是否为空）

            finalDuration = (duration > 0)
                ? duration
                : _currentPlayingMusic!.duration;

            _currentPlayingMusic = PlayingMusic(
              ret: 'OK',
              curMusic: finalTitle,
              curPlaylist: '直连播放',
              isPlaying: isPlaying,
              duration: finalDuration,
              offset: position,
            );

            debugPrint('🔄 [MiIoTDirect] 更新状态: 歌曲=${finalTitle.isEmpty ? "(未播放)" : finalTitle}, 播放=$isPlaying, 进度=$position/$finalDuration 秒');

            // 更新通知栏（只在有歌曲名时更新）
            if (finalTitle.isNotEmpty) {
              _updateNotificationFromStatus();
            }
          } else {
            // 🎯 首次轮询且还没播放音乐
            // 不创建对象，保持 null 状态，UI 会显示"暂无播放"
            debugPrint('⏭️ [MiIoTDirect] 首次轮询，还没播放音乐，保持 null 状态');
            // 🎯 不 return，继续执行到 onStatusChanged，让 UI 知道状态（即使是 null）
          }
        } else if (_currentPlayingMusic != null) {
          // 没有详情时只更新播放状态
          _currentPlayingMusic = PlayingMusic(
            ret: _currentPlayingMusic!.ret,
            curMusic: _currentPlayingMusic!.curMusic,
            curPlaylist: _currentPlayingMusic!.curPlaylist,
            isPlaying: isPlaying,
            duration: _currentPlayingMusic!.duration,
            offset: _currentPlayingMusic!.offset,
          );
          debugPrint('🔄 [MiIoTDirect] 仅更新播放状态: $isPlaying');
        }

        // 通知状态变化
        onStatusChanged?.call();
      }
    } catch (e) {
      debugPrint('⚠️ [MiIoTDirect] 状态轮询失败: $e');
    }
  }

  /// 更新通知栏状态
  void _updateNotificationFromStatus() {
    if (_audioHandler == null || _currentPlayingMusic == null) return;

    final parts = _currentPlayingMusic!.curMusic.split(' - ');
    final title = parts.isNotEmpty ? parts[0] : _currentPlayingMusic!.curMusic;
    final artist = parts.length > 1 ? parts[1] : _deviceName;

    _audioHandler!.setMediaItem(
      title: title,
      artist: artist,
      album: '直连模式',
      artUri: _albumCoverUrl,
      duration: Duration(seconds: _currentPlayingMusic!.duration),
    );
  }

  /// 初始化音频处理器（通知栏控制）
  void _initializeAudioHandler() {
    if (_audioHandler != null) {
      // 禁用本地播放器监听
      _audioHandler!.setListenToLocalPlayer(false);
      debugPrint('🔧 [MiIoTDirect] 已禁用本地播放器监听');

      // 连接通知栏控制按钮
      _audioHandler!.onPlay = () {
        debugPrint('🎵 [MiIoTDirect] 通知栏触发播放');
        play();
      };
      _audioHandler!.onPause = () {
        debugPrint('🎵 [MiIoTDirect] 通知栏触发暂停');
        pause();
      };
      _audioHandler!.onNext = () {
        debugPrint('🎵 [MiIoTDirect] 通知栏触发下一首');
        next();
      };
      _audioHandler!.onPrevious = () {
        debugPrint('🎵 [MiIoTDirect] 通知栏触发上一首');
        previous();
      };

      // 初始化通知栏显示
      _audioHandler!.setMediaItem(
        title: '正在加载...',
        artist: _deviceName,
        album: '直连模式',
      );

      debugPrint('🔧 [MiIoTDirect] 已初始化通知栏为直连模式');
    }
  }

  @override
  bool get isLocalMode => false;

  @override
  Future<void> play() async {
    debugPrint('🎵 [MiIoTDirect] 执行播放 (设备: $_deviceId)');

    try {
      final success = await _miService.resume(_deviceId);

      if (success) {
        // 更新通知栏状态
        _updateNotificationState(isPlaying: true);

        // 通知状态变化
        onStatusChanged?.call();
      } else {
        debugPrint('❌ [MiIoTDirect] 播放失败');
      }
    } catch (e) {
      debugPrint('❌ [MiIoTDirect] 播放异常: $e');
    }
  }

  @override
  Future<void> pause() async {
    debugPrint('🎵 [MiIoTDirect] 执行暂停 (设备: $_deviceId)');

    try {
      final success = await _miService.pause(_deviceId);

      if (success) {
        // 更新通知栏状态
        _updateNotificationState(isPlaying: false);

        // 通知状态变化
        onStatusChanged?.call();
      } else {
        debugPrint('❌ [MiIoTDirect] 暂停失败');
      }
    } catch (e) {
      debugPrint('❌ [MiIoTDirect] 暂停异常: $e');
    }
  }

  @override
  Future<void> next() async {
    debugPrint('🎵 [MiIoTDirect] 播放下一首');

    if (_playlist.isEmpty) {
      debugPrint('⚠️ [MiIoTDirect] 播放列表为空，无法播放下一首');
      return;
    }

    _currentIndex = (_currentIndex + 1) % _playlist.length;
    final nextMusic = _playlist[_currentIndex];
    debugPrint('🎵 [MiIoTDirect] 下一首: ${nextMusic.name} (index: $_currentIndex)');

    // 获取音乐URL并播放
    await _playMusicFromPlaylist(nextMusic);
  }

  @override
  Future<void> previous() async {
    debugPrint('🎵 [MiIoTDirect] 播放上一首');

    if (_playlist.isEmpty) {
      debugPrint('⚠️ [MiIoTDirect] 播放列表为空，无法播放上一首');
      return;
    }

    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    final prevMusic = _playlist[_currentIndex];
    debugPrint('🎵 [MiIoTDirect] 上一首: ${prevMusic.name} (index: $_currentIndex)');

    // 获取音乐URL并播放
    await _playMusicFromPlaylist(prevMusic);
  }

  /// 从播放列表播放指定音乐
  Future<void> _playMusicFromPlaylist(Music music) async {
    try {
      // Music 模型只有名字，需要通过回调获取URL
      String? url;
      if (onGetMusicUrl != null) {
        debugPrint('🔍 [MiIoTDirect] 获取音乐URL: ${music.name}');
        url = await onGetMusicUrl!(music.name);
      }

      if (url == null || url.isEmpty) {
        debugPrint('❌ [MiIoTDirect] 无法获取音乐URL: ${music.name}');
        return;
      }

      await playMusic(musicName: music.name, url: url);
    } catch (e) {
      debugPrint('❌ [MiIoTDirect] 播放失败: $e');
    }
  }

  /// 🎵 设置播放列表
  void setPlaylist(List<Music> playlist, {int startIndex = 0}) {
    _playlist = playlist;
    _currentIndex = startIndex;
    debugPrint('🎵 [MiIoTDirect] 设置播放列表: ${playlist.length} 首歌曲, 起始索引: $startIndex');
  }

  /// 获取当前播放列表
  List<Music> get playlist => List.unmodifiable(_playlist);

  @override
  Future<void> seekTo(int seconds) async {
    debugPrint('⚠️ [MiIoTDirect] 直连模式暂不支持进度拖动');
    // 小米IoT API目前不支持进度控制
  }

  @override
  Future<void> setVolume(int volume) async {
    debugPrint('🔊 [MiIoTDirect] 设置音量: $volume (设备: $_deviceId)');
    try {
      final success = await _miService.setVolume(_deviceId, volume);
      if (success) {
        debugPrint('✅ [MiIoTDirect] 音量设置成功');
      } else {
        debugPrint('❌ [MiIoTDirect] 音量设置失败');
      }
    } catch (e) {
      debugPrint('❌ [MiIoTDirect] 设置音量异常: $e');
    }
  }

  @override
  Future<void> playMusic({
    required String musicName,
    String? url,
    String? platform,
    String? songId,
  }) async {
    debugPrint('🎵 [MiIoTDirect] 播放音乐: $musicName');
    debugPrint('🔗 [MiIoTDirect] URL: $url');
    debugPrint('📱 [MiIoTDirect] 设备硬件: ${_hardware ?? "未知"}');

    if (url == null || url.isEmpty) {
      debugPrint('❌ [MiIoTDirect] 播放URL为空');
      return;
    }

    try {
      // 🎯 调用增强的播放API，传入音乐名称和硬件信息
      final success = await _miService.playMusic(
        deviceId: _deviceId,
        musicUrl: url,
        musicName: musicName, // 🎯 传入音乐名称用于生成音频ID
      );

      if (success) {
        debugPrint('✅ [MiIoTDirect] 播放成功');

        // 更新当前播放信息
        _currentPlayingMusic = PlayingMusic(
          ret: 'OK',
          curMusic: musicName,
          curPlaylist: '直连播放',
          isPlaying: true,
          duration: 0, // 直连模式无法获取时长
          offset: 0,
        );
        debugPrint('🔧 [MiIoTDirect] 已设置 _currentPlayingMusic: ${_currentPlayingMusic!.curMusic}');

        // 更新通知栏
        final parts = musicName.split(' - ');
        final title = parts.isNotEmpty ? parts[0] : musicName;
        final artist = parts.length > 1 ? parts[1] : _deviceName;

        if (_audioHandler != null) {
          _audioHandler!.setMediaItem(
            title: title,
            artist: artist,
            album: '直连模式 (${_hardware ?? "未知设备"})',
            artUri: _albumCoverUrl,
          );
          // 注意: AudioHandlerService 没有 updatePlaybackState 方法
          // 状态更新通过 setMediaItem 和播放控制方法自动处理
        }

        // 通知状态变化
        debugPrint('🔔 [MiIoTDirect] 准备调用 onStatusChanged (${onStatusChanged != null ? "已设置" : "NULL"})');
        onStatusChanged?.call();
        debugPrint('🔔 [MiIoTDirect] onStatusChanged 调用完成');
      } else {
        debugPrint('❌ [MiIoTDirect] 播放失败');
      }
    } catch (e) {
      debugPrint('❌ [MiIoTDirect] 播放异常: $e');
    }
  }

  @override
  Future<void> playMusicList({
    required String listName,
    required String musicName,
  }) async {
    debugPrint('⚠️ [MiIoTDirect] 直连模式不支持播放列表功能');
    // 直连模式需要xiaomusic服务端的歌单功能
    // 这里只能播放单曲
  }

  @override
  Future<PlayingMusic?> getCurrentStatus() async {
    // 直连模式无法主动查询播放状态
    // 返回缓存的状态
    debugPrint('🔍 [MiIoTDirect] getCurrentStatus 被调用，返回: ${_currentPlayingMusic?.curMusic ?? "null"}');
    return _currentPlayingMusic;
  }

  @override
  Future<int> getVolume() async {
    // 🎯 尝试从设备获取真实音量
    try {
      final status = await _miService.getPlayStatus(_deviceId);
      if (status != null) {
        // 🔧 小米IoT API 返回的播放状态中可能包含音量信息
        // 如果有 volume 字段，使用它；否则返回默认值
        final volume = status['volume'] as int?;
        if (volume != null) {
          debugPrint('✅ [MiIoTDirect] 获取到设备音量: $volume');
          return volume;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [MiIoTDirect] 获取音量失败: $e');
    }

    // 返回默认值
    debugPrint('⚠️ [MiIoTDirect] 使用默认音量值: 50');
    return 50;
  }

  @override
  Future<void> dispose() async {
    debugPrint('🔧 [MiIoTDirect] 释放资源');
    _statusTimer?.cancel();
    _statusTimer = null;
    _currentPlayingMusic = null;
    _albumCoverUrl = null;
    _playlist.clear();
    onStatusChanged = null;
    onGetMusicUrl = null;
  }

  /// 更新通知栏状态
  void _updateNotificationState({bool? isPlaying}) {
    if (_audioHandler == null || _currentPlayingMusic == null) {
      return;
    }

    final playing = isPlaying ?? _currentPlayingMusic!.isPlaying;

    // 注意: AudioHandlerService 通过 play/pause 方法自动更新状态
    // 这里只需要调用对应的播放控制方法
    if (playing) {
      // 通知栏会自动显示播放状态
      debugPrint('🔔 [MiIoTDirect] 通知栏状态: 播放中');
    } else {
      debugPrint('🔔 [MiIoTDirect] 通知栏状态: 已暂停');
    }
  }

  /// 设置封面图URL（外部调用）
  void setAlbumCover(String? coverUrl) {
    _albumCoverUrl = coverUrl;

    if (_audioHandler != null && _currentPlayingMusic != null) {
      final parts = _currentPlayingMusic!.curMusic.split(' - ');
      final title = parts.isNotEmpty ? parts[0] : _currentPlayingMusic!.curMusic;
      final artist = parts.length > 1 ? parts[1] : _deviceName;

      _audioHandler!.setMediaItem(
        title: title,
        artist: artist,
        album: '直连模式',
        artUri: coverUrl,
      );
    }
  }
}
