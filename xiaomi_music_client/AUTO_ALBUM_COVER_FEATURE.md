# 🖼️ 自动获取服务端本地歌曲封面图功能

## 功能说明

当播放服务端本地歌曲（如从音乐库播放）时，系统会自动搜索在线音源获取歌曲封面图，提升视觉体验。

## 实现方式

### 工作流程

1. **检测播放状态**: 在 `refreshStatus()` 中检测到正在播放的歌曲
2. **判断是否需要搜索**: 
   - 检查当前是否已有封面图
   - 检查是否已搜索过该歌曲（避免重复）
3. **自动搜索**:
   - 优先搜索 QQ 音乐（封面图质量较好）
   - 如果无结果，尝试网易云音乐
4. **提取封面图**: 从搜索结果中提取第一个匹配项的封面图 URL
5. **更新显示**: 更新 `albumCoverUrl`，首页自动显示封面图

### 关键特性

✅ **持久化缓存**: 封面图缓存保存到本地，重启 APP 后无需重新搜索
✅ **智能加载**: 优先从缓存加载，缓存未命中才搜索在线音源
✅ **异步执行**: 搜索和缓存操作在后台进行，不阻塞 UI
✅ **静默失败**: 搜索失败不影响播放功能，显示默认图标
✅ **自动切换**: 歌曲切换时自动清除旧封面，重新搜索或从缓存加载
✅ **双平台支持**: 支持 QQ 音乐和网易云音乐两个音源
✅ **自动清理**: 缓存超过 200 条时自动清理旧数据

## 修改的文件

### `lib/presentation/providers/playback_provider.dart`

#### 1. 添加搜索服务和持久化缓存

```dart
// 🖼️ 封面图自动搜索相关
final _searchService = NativeMusicSearchService();
final Map<String, String> _coverCache = {}; // 歌曲名 -> 封面URL 的缓存
static const String _coverCacheKey = 'album_cover_cache';
static const int _maxCacheSize = 200; // 最多缓存200首歌的封面

// 构造函数中加载缓存
PlaybackNotifier(this.ref) : super(...) {
  _loadCoverCache(); // 异步加载持久化缓存
}
```

#### 2. 添加缓存加载和保存方法

```dart
/// 🖼️ 从本地存储加载封面图缓存
Future<void> _loadCoverCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_coverCacheKey);
    if (cacheJson != null && cacheJson.isNotEmpty) {
      final Map<String, dynamic> decoded = jsonDecode(cacheJson);
      _coverCache.clear();
      decoded.forEach((key, value) {
        if (value is String) {
          _coverCache[key] = value;
        }
      });
      print('🖼️ [CoverCache] 已加载 ${_coverCache.length} 条封面缓存');
    }
  } catch (e) {
    print('🖼️ [CoverCache] 加载缓存失败: $e');
  }
}

/// 🖼️ 保存封面图缓存到本地存储
Future<void> _saveCoverCache() async {
  try {
    // 限制缓存大小，移除最早的条目
    if (_coverCache.length > _maxCacheSize) {
      final keysToRemove = _coverCache.keys.take(_coverCache.length - _maxCacheSize).toList();
      for (final key in keysToRemove) {
        _coverCache.remove(key);
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = jsonEncode(_coverCache);
    await prefs.setString(_coverCacheKey, cacheJson);
    print('🖼️ [CoverCache] 已保存 ${_coverCache.length} 条封面缓存');
  } catch (e) {
    print('🖼️ [CoverCache] 保存缓存失败: $e');
  }
}
```

#### 3. 添加自动搜索方法（优先从缓存加载）

```dart
/// 🖼️ 自动搜索并获取歌曲封面图（用于服务端本地歌曲）
Future<void> _autoFetchAlbumCover(String songName) async {
  // 🎯 先检查缓存
  if (_coverCache.containsKey(songName)) {
    final cachedUrl = _coverCache[songName]!;
    print('🖼️ [AutoCover] 从缓存加载封面: $songName');
    updateAlbumCover(cachedUrl);
    return;
  }
  
  try {
    // 优先搜索QQ音乐
    List<OnlineMusicResult> results = await _searchService.searchQQ(
      query: songName,
      page: 1,
    );
    
    // 如果QQ音乐没有结果，尝试网易云音乐
    if (results.isEmpty) {
      results = await _searchService.searchNetease(
        query: songName,
        page: 1,
      );
    }
    
    // 从搜索结果中提取封面图
    if (results.isNotEmpty) {
      final firstResult = results.first;
      if (firstResult.picture != null && firstResult.picture!.isNotEmpty) {
        // 🎯 保存到缓存
        _coverCache[songName] = firstResult.picture!;
        _saveCoverCache(); // 异步保存，不阻塞主流程
        
        updateAlbumCover(firstResult.picture!);
      }
    }
  } catch (e) {
    // 静默失败，不影响播放
  }
}
```

#### 4. 在 refreshStatus() 中触发自动加载（优先缓存，后搜索）

```dart
// 🖼️ 自动搜索封面图（适用于服务端本地歌曲）
if (currentMusic != null && 
    (state.albumCoverUrl == null || state.albumCoverUrl!.isEmpty)) {
  // 异步搜索封面图，不阻塞主流程（内部会优先检查缓存）
  _autoFetchAlbumCover(currentMusic.curMusic).catchError((e) {
    print('🖼️ [AutoCover] 异步搜索封面失败: $e');
  });
}
```

## 使用场景

### 场景 1: 播放本地音乐库歌曲

1. 用户在**音乐库**页面点击播放一首歌
2. 返回**控制面板**页面
3. **预期效果**: 
   - 初始显示默认音符图标
   - 几秒后自动显示搜索到的封面图
   - 控制台输出搜索日志

### 场景 2: 播放在线搜索歌曲

1. 用户在**搜索**页面搜索并播放歌曲
2. 返回**控制面板**页面
3. **预期效果**:
   - 直接显示搜索结果中的封面图
   - 不会触发自动搜索（因为已有封面图）

### 场景 3: 切换歌曲

1. 当前播放歌曲 A（已显示封面）
2. 切换到歌曲 B（本地歌曲）
3. **预期效果**:
   - 立即清除歌曲 A 的封面
   - 显示默认图标
   - 如果缓存中有歌曲 B 的封面，立即显示
   - 否则自动搜索并显示

### 场景 4: 重启 APP（持久化缓存生效）⭐

1. 播放本地歌曲 A（首次播放，搜索封面）
2. 等待封面显示并缓存
3. 完全退出并重启 APP
4. 再次播放歌曲 A
5. **预期效果**:
   - ✅ 立即从缓存加载封面，无需重新搜索
   - ✅ 控制台输出: `🖼️ [CoverCache] 已加载 X 条封面缓存`
   - ✅ 控制台输出: `🖼️ [AutoCover] 从缓存加载封面: 歌曲A`

## 日志输出示例

### APP 启动时加载缓存

```
🖼️ [CoverCache] 已加载 15 条封面缓存
```

### 首次搜索并保存缓存

```
🖼️ [AutoCover] 开始自动搜索封面: 夜曲
🖼️ [AutoCover] 找到封面: https://y.gtimg.cn/music/photo_new/T002R300x300M000003DFRzD192KKD.jpg
🖼️ [AutoCover] 来源: 夜曲 - 周杰伦
🖼️ [CoverCache] 已保存 16 条封面缓存
[Playback] 🖼️  封面图已更新: https://y.gtimg.cn/music/photo_new/T002R300x300M000003DFRzD192KKD.jpg
```

### 从缓存加载（重启后或再次播放）

```
🖼️ [AutoCover] 从缓存加载封面: 夜曲
[Playback] 🖼️  封面图已更新: https://y.gtimg.cn/music/photo_new/T002R300x300M000003DFRzD192KKD.jpg
```

### QQ音乐无结果，尝试网易云

```
🖼️ [AutoCover] 开始自动搜索封面: 某首冷门歌曲
🖼️ [AutoCover] QQ音乐无结果，尝试网易云音乐
🖼️ [AutoCover] 找到封面: https://p1.music.126.net/xxxxx.jpg
🖼️ [AutoCover] 来源: 某首冷门歌曲 - 某艺术家
🖼️ [CoverCache] 已保存 17 条封面缓存
```

### 搜索失败

```
🖼️ [AutoCover] 开始自动搜索封面: 非常冷门的歌曲名
🖼️ [AutoCover] QQ音乐无结果，尝试网易云音乐
🖼️ [AutoCover] 未找到搜索结果
```

### 缓存自动清理

```
🖼️ [CoverCache] 清理缓存，当前大小: 200
🖼️ [CoverCache] 已保存 200 条封面缓存
```

## 性能优化

1. **持久化缓存**: 使用 SharedPreferences 保存封面图 URL，重启后无需重新搜索
2. **内存缓存**: 使用 `Map<String, String>` 在内存中缓存封面图 URL，快速访问
3. **缓存优先**: 优先从缓存加载，命中率高，减少网络请求
4. **异步执行**: 搜索和缓存操作不阻塞播放状态刷新，用户体验流畅
5. **双平台降级**: QQ音乐失败后自动尝试网易云，提高成功率
6. **自动清理**: 限制缓存大小为 200 条，自动清理旧数据，避免占用过多存储空间
7. **静默失败**: 搜索失败不影响播放，不弹出错误提示

## 注意事项

### 限制

- 只搜索歌曲名称，不包含艺术家信息（可能导致匹配不准确）
- 只取第一个搜索结果的封面图
- 缓存大小限制为 200 条（超过后自动清理旧数据）
- 缓存使用歌曲名称作为 key，不同版本的同名歌曲会使用同一封面

### 已实现的功能 ✅

- [x] 持久化缓存（SharedPreferences）
- [x] 限制缓存大小（200 条）
- [x] 自动清理旧数据（FIFO 策略）
- [x] 双平台支持（QQ音乐 + 网易云音乐）

### 可能的改进

- [ ] 添加艺术家信息到搜索关键词，提高匹配准确度
- [ ] 支持更多音源平台（酷我、酷狗等）
- [ ] 实现 LRU（最近最少使用）缓存策略
- [ ] 添加配置选项让用户控制是否启用自动搜索
- [ ] 添加手动清除缓存的功能

## 测试步骤

### 1. 准备测试环境

确保服务端有本地音乐库，且包含一些歌曲。

### 2. 测试本地歌曲封面

1. 打开**音乐库**页面
2. 点击播放任意一首歌
3. 切换到**控制面板**
4. 观察封面图变化：
   - 初始：默认音符图标
   - 几秒后：显示搜索到的封面图

### 3. 测试在线歌曲封面

1. 打开**搜索**页面
2. 搜索并播放任意歌曲
3. 切换到**控制面板**
4. 观察封面图：应该立即显示搜索结果中的封面图

### 4. 测试切歌场景

1. 播放本地歌曲 A（等待封面显示）
2. 切换到音乐库，播放歌曲 B
3. 返回**控制面板**
4. 观察封面图：
   - 立即清除歌曲 A 的封面
   - 显示默认图标
   - 几秒后显示歌曲 B 的封面

### 5. 测试持久化缓存（重启场景）⭐

1. 播放一首本地歌曲（如"夜曲"）
2. 等待封面显示
3. 查看日志确认缓存已保存：
   ```
   🖼️ [CoverCache] 已保存 X 条封面缓存
   ```
4. **完全退出 APP**（不是后台）
5. 重新启动 APP
6. 查看日志确认缓存已加载：
   ```
   🖼️ [CoverCache] 已加载 X 条封面缓存
   ```
7. 再次播放同一首歌
8. 观察封面：
   - ✅ 应该立即显示（从缓存加载）
   - ✅ 不会看到"搜索中"的过程
9. 查看日志确认从缓存加载：
   ```
   🖼️ [AutoCover] 从缓存加载封面: 夜曲
   ```

### 6. 检查日志

在控制台查看搜索日志，确认：
- 搜索请求是否发送
- 搜索结果是否返回
- 封面图是否正确提取和更新
- 缓存是否正确加载和保存

## 与现有功能的兼容性

✅ **与在线播放兼容**: 在线播放时直接使用搜索结果的封面，不触发自动搜索
✅ **与歌曲切换兼容**: 切歌时正确清除旧封面，搜索新封面
✅ **与进度显示兼容**: 不影响进度条和播放状态的显示
✅ **与错误处理兼容**: 搜索失败不影响播放功能

## 相关文件

- `lib/presentation/providers/playback_provider.dart` - 主要实现
- `lib/data/services/native_music_search_service.dart` - 搜索服务
- `lib/data/models/online_music_result.dart` - 搜索结果模型
- `lib/presentation/pages/control_panel_page.dart` - 封面图显示

## 版本历史

- **v1.0** (2025-10-04): 初始实现，支持 QQ 音乐和网易云音乐，内存缓存
- **v1.1** (2025-10-04): 添加持久化缓存（SharedPreferences），支持重启后快速加载

