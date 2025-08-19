import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../providers/device_provider.dart';
import 'playlist_detail_page.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_layout.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({super.key});

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(playlistProvider);

    return Scaffold(
      key: const ValueKey('playlist_scaffold'),
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _buildContent(playlistState),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: AppLayout.bottomOverlayHeight(context) + 8,
        ),
        child: FloatingActionButton(
          key: const ValueKey('playlist_fab'),
          onPressed: () => _showCreatePlaylistDialog(),
          tooltip: '新建列表',
          child: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent(PlaylistState playlistState) {
    if (playlistState.isLoading && playlistState.playlists.isEmpty) {
      return _buildLoadingIndicator();
    }
    if (playlistState.error != null) {
      return _buildErrorState(playlistState.error!);
    }
    if (playlistState.playlists.isEmpty) {
      return _buildInitialState();
    }
    return _buildPlaylistsList(playlistState);
  }

  Widget _buildInitialState() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      key: const ValueKey('playlist_initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 80,
            color: onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            '你的播放列表',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在这里创建和管理你的音乐收藏',
            style: TextStyle(fontSize: 16, color: onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      key: const ValueKey('playlist_loading'),
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String error) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      key: const ValueKey('playlist_error'),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 20),
            Text(
              '加载列表失败',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(fontSize: 15, color: onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed:
                  () => ref.read(playlistProvider.notifier).refreshPlaylists(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(PlaylistState playlistState) {
    return RefreshIndicator(
      key: const ValueKey('playlist_refresh'),
      onRefresh: () => ref.read(playlistProvider.notifier).refreshPlaylists(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              AppLayout.contentBottomPadding(context),
            ),
            sliver: SliverList.builder(
              key: const ValueKey('playlist_list'),
              itemCount: playlistState.playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlistState.playlists[index];
                final deletable = playlistState.deletablePlaylists.contains(
                  playlist.name,
                );
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0.5,
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -3,
                    ),
                    minLeadingWidth: 0,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      playlist.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      '${playlist.count ?? 0}首歌曲',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded),
                          color: Theme.of(context).colorScheme.primary,
                          iconSize: 20,
                          tooltip: '播放列表',
                          onPressed: () async {
                            final did =
                                ref.read(deviceProvider).selectedDeviceId;
                            if (did == null) {
                              if (mounted) {
                                AppSnackBar.showText(context, '请先在控制页选择播放设备');
                              }
                              return;
                            }
                            await ref
                                .read(playlistProvider.notifier)
                                .playPlaylist(
                                  deviceId: did,
                                  playlistName: playlist.name,
                                );
                          },
                        ),
                        PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (value) async {
                            switch (value) {
                              case 'open':
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PlaylistDetailPage(
                                          playlistName: playlist.name,
                                        ),
                                  ),
                                );
                                break;
                              case 'delete':
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: const Text('删除列表'),
                                        content: Text(
                                          '确定删除 "${playlist.name}" 吗？此操作不可撤销。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, true),
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                );
                                if (ok == true) {
                                  try {
                                    await ref
                                        .read(playlistProvider.notifier)
                                        .deletePlaylist(playlist.name);
                                    if (mounted) {
                                      AppSnackBar.show(
                                        context,
                                        SnackBar(
                                          content: Text(
                                            '✅ 测试成功：已删除列表 "${playlist.name}"',
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print(
                                      '🧪 [测试] 删除播放列表失败: ${playlist.name}, 错误: $e',
                                    );
                                    if (mounted) {
                                      AppSnackBar.show(
                                        context,
                                        SnackBar(
                                          content: Text(
                                            '🧪 测试结果：删除失败\n播放列表: ${playlist.name}\n错误: $e',
                                          ),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 8),
                                        ),
                                      );
                                    }
                                  }
                                }
                                break;
                            }
                          },
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Text('打开'),
                                ),
                                if (deletable)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除列表'),
                                  ),
                              ],
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => PlaylistDetailPage(
                                playlistName: playlist.name,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    bool _requestedFocus = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final onSurface = Theme.of(context).colorScheme.onSurface;
        final focusNode = FocusNode();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canCreate = controller.text.trim().isNotEmpty;
            // 延后聚焦，避免与底部面板动画同时触发造成卡顿
            if (!_requestedFocus) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await Future.delayed(const Duration(milliseconds: 180));
                if (focusNode.canRequestFocus) {
                  FocusScope.of(context).requestFocus(focusNode);
                }
              });
              _requestedFocus = true;
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '新建列表',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: false,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: '列表名称',
                        hintText: '例如：我的最爱',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: onSurface.withOpacity(0.1),
                          ),
                        ),
                        filled: true,
                        fillColor: onSurface.withOpacity(0.04),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                !canCreate
                                    ? null
                                    : () async {
                                      final name = controller.text.trim();
                                      try {
                                        await ref
                                            .read(playlistProvider.notifier)
                                            .createPlaylist(name);
                                        if (mounted) Navigator.pop(context);
                                        if (mounted) {
                                          AppSnackBar.show(
                                            context,
                                            SnackBar(
                                              content: Text('"$name" 已创建'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) Navigator.pop(context);
                                        if (mounted) {
                                          AppSnackBar.show(
                                            context,
                                            SnackBar(
                                              content: Text('创建失败: $e'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('创建'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
