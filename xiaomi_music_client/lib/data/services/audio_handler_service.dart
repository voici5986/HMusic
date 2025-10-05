import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// 音频后台服务处理器
/// 负责管理系统媒体通知和后台播放
class AudioHandlerService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  // 当前播放的媒体项
  MediaItem? _currentMediaItem;

  AudioHandlerService({required AudioPlayer player}) : _player = player {
    _init();
  }

  void _init() {
    // 监听播放状态变化
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      // 更新播放状态到系统通知
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
        processingState: _mapProcessingState(processingState),
        updatePosition: _player.position,
      ));
    });

    // 监听播放进度
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // 监听播放完成
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  /// 映射 just_audio 的 ProcessingState 到 audio_service 的 AudioProcessingState
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

  /// 更新当前媒体信息（歌曲名、艺术家、封面等）
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
  }

  @override
  Future<void> pause() async {
    debugPrint('🎵 [AudioHandler] 暂停');
    await _player.pause();
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
    // 这里需要通过回调通知 LocalPlaybackStrategy
    // 暂时先触发一个事件
    customAction('skipToNext');
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('🎵 [AudioHandler] 上一首');
    // 这里需要通过回调通知 LocalPlaybackStrategy
    customAction('skipToPrevious');
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    debugPrint('🎵 [AudioHandler] 自定义操作: $name');
    // 可以通过广播事件或回调来处理
    return super.customAction(name, extras);
  }

  /// 清除通知
  Future<void> clearNotification() async {
    await stop();
    mediaItem.add(null);
  }
}
