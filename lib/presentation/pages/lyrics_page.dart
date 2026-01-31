import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/playback_provider.dart';
import '../providers/lyric_provider.dart';

/// 歌词页面 - 支持沉浸模式（顶部/底部控制栏自动隐藏）
class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  final ScrollController _scrollController = ScrollController();
  int _lastCurrentLine = -1;
  String? _lastSongName;
  double? _draggingProgress;

  // 🎭 沉浸模式状态
  bool _showControls = true;
  Timer? _autoHideTimer;

  /// 自动隐藏延时（秒）
  static const _autoHideDuration = Duration(seconds: 5);

  /// 控制栏动画时长
  static const _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // 页面打开后 5 秒自动进入沉浸模式
    _startAutoHideTimer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 沉浸模式控制
  // ---------------------------------------------------------------------------

  /// 切换控制栏显示/隐藏
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startAutoHideTimer();
    } else {
      _autoHideTimer?.cancel();
    }
  }

  /// 显示控制栏并启动自动隐藏计时器
  void _showControlsAndStartTimer() {
    if (_showControls) return;
    setState(() {
      _showControls = true;
    });
    _startAutoHideTimer();
  }

  /// 启动 / 重置 5 秒自动隐藏计时器
  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideDuration, () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  /// 任何用户交互都应调用此方法，重置自动隐藏计时器
  void _resetAutoHideTimer() {
    if (_showControls) {
      _startAutoHideTimer();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final lyricState = ref.watch(lyricProvider);
    final current = playback.currentMusic;
    final coverUrl = playback.albumCoverUrl;

    // 🔧 检测歌曲切换，自动重新加载歌词
    final currentSongName = current?.curMusic ?? '';
    if (currentSongName.isNotEmpty && currentSongName != _lastSongName) {
      debugPrint('🎤 [LyricsPage] 检测到歌曲切换: $_lastSongName -> $currentSongName');
      _lastSongName = currentSongName;
      _lastCurrentLine = -1;
      _draggingProgress = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('🎤 [LyricsPage] 自动重新加载歌词');
          ref.read(lyricProvider.notifier).loadLyrics(currentSongName);
        }
      });
    }

    // 🔧 计算当前显示时间
    final displayTime = _draggingProgress != null
        ? (_draggingProgress! * (current?.duration ?? 0)).round()
        : (current?.offset ?? 0);

    // 获取当前歌词行
    final currentLineIndex = current != null
        ? ref.read(lyricProvider.notifier).getCurrentLineIndex(displayTime)
        : -1;

    // 🔧 滚动逻辑
    if (currentLineIndex >= 0 && currentLineIndex != _lastCurrentLine) {
      _lastCurrentLine = currentLineIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_draggingProgress != null) {
            _scrollToLineInstant(currentLineIndex);
          } else {
            _scrollToLine(currentLineIndex);
          }
        }
      });
    }

    // =====================================================================
    // 使用 Stack 布局：歌词全屏 + 控制栏覆盖在上下方
    // =====================================================================
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Layer 0: 背景模糊图 ──
          if (coverUrl != null && coverUrl.isNotEmpty)
            Positioned.fill(
              child: _buildBlurredBackground(coverUrl),
            ),

          // ── Layer 1: 歌词区域（全屏） ──
          Positioned.fill(
            child: SafeArea(
              child: GestureDetector(
                // 点击空白区域（ListView 的 padding）切换控制栏
                onTap: _toggleControls,
                behavior: HitTestBehavior.opaque,
                child: lyricState.isLoading
                    ? _buildLoading()
                    : (lyricState.lyric == null || !lyricState.lyric!.hasLyrics)
                        ? _buildNoLyrics()
                        : _buildLyricsContent(
                            lyricState, currentLineIndex, displayTime),
              ),
            ),
          ),

          // ── Layer 2: 顶部信息栏（动画覆盖层） ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedSlide(
                  offset: Offset(0, _showControls ? 0 : -1),
                  duration: _animationDuration,
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: _animationDuration,
                    child: _buildTopBar(current),
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 3: 底部控制栏（动画覆盖层） ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedSlide(
                  offset: Offset(0, _showControls ? 0 : 1),
                  duration: _animationDuration,
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: _animationDuration,
                    child: _buildBottomControls(current),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 背景
  // ---------------------------------------------------------------------------

  Widget _buildBlurredBackground(String coverUrl) {
    return Stack(
      children: [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            imageBuilder: (context, imageProvider) {
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              );
            },
            errorWidget: (context, url, error) => Container(
              color: Colors.black,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 顶部信息栏
  // ---------------------------------------------------------------------------

  Widget _buildTopBar(dynamic currentMusic) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentMusic?.curMusic ?? '暂无播放',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMusic?.curPlaylist ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 关闭按钮
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // 歌词内容
  // ---------------------------------------------------------------------------

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildNoLyrics() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 60,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无歌词',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '纯享音乐模式',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsContent(
      dynamic lyricState, int currentLineIndex, int displayTime) {
    final lyric = lyricState.lyric!;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    // 🔧 沉浸模式下控制栏高度为 0（全屏歌词）
    const topBarHeight = 92.0;
    const bottomControlHeight = 130.0;
    final effectiveTopBar = _showControls ? topBarHeight : 0.0;
    final effectiveBottomBar = _showControls ? bottomControlHeight : 0.0;

    final lyricsAreaHeight = screenHeight -
        safeAreaTop -
        safeAreaBottom -
        effectiveTopBar -
        effectiveBottomBar;

    const itemHeight = 90.0;
    final topPadding = (lyricsAreaHeight * 0.4 - (itemHeight / 2))
        .clamp(0.0, double.infinity);
    final bottomPadding = (lyricsAreaHeight * 0.6 - (itemHeight / 2))
        .clamp(0.0, double.infinity);

    // 🔧 沉浸模式下为控制栏预留空间（防止歌词被遮挡）
    final extraTopPadding = _showControls ? topBarHeight : 0.0;
    final extraBottomPadding = _showControls ? bottomControlHeight : 0.0;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: topPadding + extraTopPadding,
        bottom: bottomPadding + extraBottomPadding,
      ),
      itemCount: lyric.lines.length,
      itemBuilder: (context, index) {
        final line = lyric.lines[index];
        final isCurrent = index == currentLineIndex;

        return GestureDetector(
          onTap: () {
            if (!_showControls) {
              // 沉浸模式下点击 → 显示控制栏
              _showControlsAndStartTimer();
              return;
            }
            // 控制栏可见时，本地模式支持点击歌词跳转
            final playbackState = ref.read(playbackProvider);
            if (playbackState.isLocalMode) {
              ref.read(playbackProvider.notifier).seekTo(line.timestamp);
              _resetAutoHideTimer();
            }
          },
          child: _buildLyricLine(line.text, isCurrent),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 单行歌词
  // ---------------------------------------------------------------------------

  Widget _buildLyricLine(String text, bool isCurrent) {
    final displayText = text.isEmpty ? '♪' : text;
    final themeColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 90.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isCurrent ? themeColor : Colors.white,
                    fontSize: isCurrent ? 26 : 16,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(false),
                      const SizedBox(width: 8),
                      _buildDot(true),
                      const SizedBox(width: 8),
                      _buildDot(false),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(active ? 0.9 : 0.5),
        shape: BoxShape.circle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 底部控制栏
  // ---------------------------------------------------------------------------

  Widget _buildBottomControls(dynamic currentMusic) {
    final isPlaying = currentMusic?.isPlaying ?? false;

    // 🎵 只有本地播放模式才允许拖动进度条
    final playbackState = ref.watch(playbackProvider);
    final canSeek =
        playbackState.isLocalMode && (currentMusic?.duration ?? 0) > 0;

    final displayProgress = _draggingProgress ??
        ((currentMusic?.duration ?? 0) > 0
            ? ((currentMusic?.offset ?? 0) / (currentMusic?.duration ?? 1))
                .clamp(0.0, 1.0)
            : 0.0);

    final displayTime = _draggingProgress != null
        ? (_draggingProgress! * (currentMusic?.duration ?? 0)).round()
        : (currentMusic?.offset ?? 0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          Row(
            children: [
              Text(
                _fmt(displayTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: displayProgress,
                    onChanged: canSeek
                        ? (v) {
                            setState(() {
                              _draggingProgress = v;
                            });
                            _resetAutoHideTimer(); // 拖动进度条时重置计时器
                          }
                        : null,
                    onChangeEnd: canSeek
                        ? (v) {
                            final seekSeconds =
                                (v * (currentMusic!.duration)).round();
                            setState(() {
                              _draggingProgress = null;
                            });
                            ref
                                .read(playbackProvider.notifier)
                                .seekTo(seekSeconds);
                            _resetAutoHideTimer();
                          }
                        : null,
                    activeColor: Colors.white.withOpacity(0.85),
                    inactiveColor: Colors.white.withOpacity(0.25),
                  ),
                ),
              ),
              Text(
                _fmt(currentMusic?.duration ?? 0),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                onPressed: () {
                  ref.read(playbackProvider.notifier).previous();
                  _resetAutoHideTimer();
                },
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onPressed: () {
                  if (isPlaying) {
                    ref.read(playbackProvider.notifier).pauseMusic();
                  } else {
                    ref.read(playbackProvider.notifier).resumeMusic();
                  }
                  _resetAutoHideTimer();
                },
                isPrimary: true,
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                onPressed: () {
                  ref.read(playbackProvider.notifier).next();
                  _resetAutoHideTimer();
                },
              ),
            ],
          ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isPrimary
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          size: isPrimary ? 32 : 28,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  String _fmt(int seconds) {
    if (seconds <= 0) return '0:00';
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _scrollToLine(int lineIndex) {
    if (!_scrollController.hasClients) return;

    const itemHeight = 90.0;
    final targetOffset = lineIndex * itemHeight;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToLineInstant(int lineIndex) {
    if (!_scrollController.hasClients) return;

    const itemHeight = 90.0;
    final targetOffset = lineIndex * itemHeight;

    _scrollController.jumpTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }
}
