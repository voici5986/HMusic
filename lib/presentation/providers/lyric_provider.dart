import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lyric.dart';
import '../../data/services/lyric_service.dart';
import '../../data/services/music_api_service.dart';
import '../../data/services/native_music_search_service.dart';
import 'dio_provider.dart';

/// 歌词状态
class LyricState {
  final Lyric? lyric;
  final bool isLoading;
  final String? error;
  final String? currentSongName; // 当前加载歌词的歌曲名

  const LyricState({
    this.lyric,
    this.isLoading = false,
    this.error,
    this.currentSongName,
  });

  LyricState copyWith({
    Lyric? Function()? lyric, // 🔧 使用函数类型以支持显式设置 null
    bool? isLoading,
    String? error,
    String? currentSongName,
  }) {
    return LyricState(
      lyric: lyric != null ? lyric() : this.lyric,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentSongName: currentSongName ?? this.currentSongName,
    );
  }
}

/// 歌词Provider
class LyricNotifier extends StateNotifier<LyricState> {
  final Ref ref;
  LyricService? _lyricService;

  LyricNotifier(this.ref) : super(const LyricState());

  /// 初始化歌词服务
  void _ensureServiceInitialized() {
    if (_lyricService != null) return;

    final apiService = ref.read(apiServiceProvider);
    if (apiService == null) {
      debugPrint('❌ [LyricProvider] API服务未初始化');
      return;
    }

    final nativeSearch = ref.read(nativeMusicSearchServiceProvider);
    _lyricService = LyricService(
      musicApi: apiService,
      nativeSearch: nativeSearch,
    );

    debugPrint('✅ [LyricProvider] 歌词服务已初始化');
  }

  /// 加载歌词
  Future<void> loadLyrics(String musicName, {bool autoScrape = true, bool forceReload = false}) async {
    // 🔧 防止重复加载相同歌曲的歌词（除非强制重新加载）
    if (!forceReload && state.currentSongName == musicName && state.lyric != null && !state.isLoading) {
      debugPrint('🎤 [LyricProvider] 歌词已加载，跳过: $musicName');
      return;
    }

    _ensureServiceInitialized();

    if (_lyricService == null) {
      state = state.copyWith(
        error: '歌词服务未初始化',
        isLoading: false,
      );
      return;
    }

    try {
      debugPrint('🎤 [LyricProvider] 开始加载歌词: $musicName');

      // 🔧 先清除旧歌词，避免显示上一首歌的内容
      state = state.copyWith(
        isLoading: true,
        error: null,
        currentSongName: musicName,
        lyric: () => null, // 立即清空旧歌词
      );

      final lyric = await _lyricService!.getLyrics(
        musicName: musicName,
        autoScrape: autoScrape,
      );

      // 🔧 检查歌曲是否已经切换（避免异步加载完成后覆盖新歌曲的歌词）
      if (state.currentSongName != musicName) {
        debugPrint('⚠️ [LyricProvider] 歌曲已切换，放弃加载: $musicName');
        return;
      }

      state = state.copyWith(
        lyric: () => lyric,
        isLoading: false,
        error: null,
      );

      if (lyric.hasLyrics) {
        debugPrint('✅ [LyricProvider] 歌词加载成功: ${lyric.lines.length} 行');
      } else {
        debugPrint('⚠️ [LyricProvider] 无歌词');
      }
    } catch (e) {
      debugPrint('❌ [LyricProvider] 加载歌词失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: '加载歌词失败: ${e.toString()}',
        lyric: () => Lyric.empty(),
      );
    }
  }

  /// 清除歌词
  void clearLyrics() {
    state = const LyricState();
  }

  /// 根据当前时间获取当前歌词行索引
  int getCurrentLineIndex(int currentTime) {
    if (state.lyric == null) return -1;
    return state.lyric!.getCurrentLineIndex(currentTime);
  }
}

/// 歌词Provider
final lyricProvider = StateNotifierProvider<LyricNotifier, LyricState>((ref) {
  return LyricNotifier(ref);
});
