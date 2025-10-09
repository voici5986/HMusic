import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// 音频后台服务处理器
/// 负责管理系统媒体通知和后台播放
class AudioHandlerService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  // 🔧 暴露 AudioPlayer 实例,供 LocalPlaybackStrategy 共享使用
  AudioPlayer get player => _player;

  MediaItem? _currentMediaItem;

  AudioHandlerService({required AudioPlayer player}) : _player = player {
    _init();
  }

  void _init() {
    debugPrint('🧩 [AudioHandler] 初始化');
    // 初始状态
    playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: const [MediaControl.play],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      ),
    );

    // 监听播放状态变化
    _player.playerStateStream.listen((playerState) {
      debugPrint('🧩 [AudioHandler] playerState: playing=${playerState.playing}, state=${playerState.processingState}');
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      // 🔧 将 ready 和 completed 状态都映射为 ready,确保通知栏正常显示
      final mappedState = _mapProcessingState(processingState);
      final effectiveState = (mappedState == AudioProcessingState.ready ||
                             mappedState == AudioProcessingState.completed)
          ? AudioProcessingState.ready
          : mappedState;

      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: effectiveState,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });

    // 监听播放进度
    _player.positionStream.listen((position) {
      debugPrint('🧩 [AudioHandler] position: ${position.inMilliseconds}ms');
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // 监听缓冲进度和倍速变化以同步到系统
    _player.bufferedPositionStream.listen((bp) {
      debugPrint('🧩 [AudioHandler] buffered: ${bp.inMilliseconds}ms');
      playbackState.add(playbackState.value.copyWith(bufferedPosition: bp));
    });
    _player.speedStream.listen((sp) {
      debugPrint('🧩 [AudioHandler] speed: $sp');
      playbackState.add(playbackState.value.copyWith(speed: sp));
    });

    // 监听时长变化，及时更新媒体项以便控制中心显示进度条
    _player.durationStream.listen((d) {
      if (_currentMediaItem != null && d != null) {
        _currentMediaItem = _currentMediaItem!.copyWith(duration: d);
        mediaItem.add(_currentMediaItem);
      }
    });

    // 播放完成自动下一首
    _player.processingStateStream.listen((state) {
      debugPrint('🧩 [AudioHandler] processingState: $state');
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> setMediaItem({
    required String title,
    String? artist,
    String? album,
    String? artUri,
    Duration? duration,
  }) async {
    _currentMediaItem = MediaItem(
      id: title,
      title: title,
      artist: artist ?? '未知艺术家',
      album: album ?? '本地播放',
      artUri: artUri != null && artUri.isNotEmpty ? Uri.parse(artUri) : null,
      duration: duration,
    );

    mediaItem.add(_currentMediaItem);
    debugPrint('🎵 [AudioHandler] 更新媒体信息: $title - $artist');
  }

  @override
  Future<void> play() async {
    debugPrint('🎵 [AudioHandler] 播放');
    await _player.play();

    // 🔧 强制更新播放状态,确保通知栏显示正确
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
    ));
  }

  @override
  Future<void> pause() async {
    debugPrint('🎵 [AudioHandler] 暂停');
    await _player.pause();

    // 🔧 强制更新暂停状态,确保通知栏显示正确
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.ready,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
    ));
  }

  @override
  Future<void> stop() async {
    debugPrint('🎵 [AudioHandler] 停止');
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint('🎵 [AudioHandler] 跳转到: ${position.inSeconds}s');
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('🎵 [AudioHandler] 下一首');
    customAction('skipToNext');
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('🎵 [AudioHandler] 上一首');
    customAction('skipToPrevious');
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    debugPrint('🎵 [AudioHandler] 自定义操作: $name');
    return super.customAction(name, extras);
  }

  Future<void> clearNotification() async {
    await stop();
    mediaItem.add(null);
  }
}
