# LX Custom Source JS脚本集成指南

## 🎯 **目标**

将 `lx-custom-source.js` 脚本集成到你的Flutter应用中，作为默认的JS音乐脚本，用于获取直接的音频流链接。

## 📁 **文件说明**

### `lx-custom-source.js`
这是一个LX Music的API服务器脚本，支持以下音乐平台：
- **tx**: QQ音乐 (支持128k, 320k, flac, flac24bit)
- **wy**: 网易云音乐 (支持128k)
- **kw**: 酷我音乐 (支持128k)
- **kg**: 酷狗音乐 (支持128k)
- **mg**: 咪咕音乐 (支持128k)

## 🔧 **集成步骤**

### 1. **将JS文件添加到Flutter项目**

将 `lx-custom-source.js` 文件复制到你的Flutter项目的 `assets/js/` 目录下：

```
xiaomi_music_client/
├── assets/
│   └── js/
│       └── lx-custom-source.js
├── lib/
└── pubspec.yaml
```

### 2. **更新pubspec.yaml**

在 `pubspec.yaml` 文件中添加JS文件作为资源：

```yaml
flutter:
  assets:
    - assets/js/lx-custom-source.js
```

### 3. **修改WebViewJsSourceService**

确保你的 `WebViewJsSourceService` 能够加载这个JS脚本。

### 4. **代码集成**

我已经在你的 `music_search_page.dart` 中添加了集成代码：

```dart
// 🎯 新增：尝试使用lx-custom-source.js获取直接音频流链接
Future<String?> _getDirectStreamViaLxScript(OnlineMusicResult item) async {
  try {
    final webSvc = await ref.read(webviewJsSourceServiceProvider.future);
    if (webSvc == null) {
      throw Exception('JS源服务未就绪');
    }

    // 使用resolveMusicUrl方法，这是WebViewJsSourceService的标准方法
    final directStreamUrl = await webSvc.resolveMusicUrl(
      platform: item.platform ?? 'qq',
      songId: item.songId ?? '',
    );

    if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
      print('✅ [Play] 通过JS源获取到链接: $directStreamUrl');
      
      // 检查是否是直接的音频流链接
      if (directStreamUrl.contains('.mp3') || directStreamUrl.contains('.m4a') || directStreamUrl.contains('.flac')) {
        if (!directStreamUrl.contains('ws.stream.qqmusic.qq.com')) {
          print('✅ [Play] 确认是直接音频流链接');
          return directStreamUrl;
        }
      }
    }
    
    return null;
  } catch (e) {
    print('⚠️ [Play] JS源获取直接流失败: $e');
    return null;
  }
}
```

## 🎵 **播放流程**

### **新的播放逻辑**

1. **点击歌曲** → 解析播放链接
2. **检测链接类型** → 如果是QQ音乐链接（包含`ws.stream.qqmusic.qq.com`）
3. **尝试获取直接流** → 使用lx-custom-source.js脚本
4. **验证链接格式** → 确保是直接的音频流链接
5. **直接播放** → 调用播放接口

### **链接类型检测**

```dart
// 🎯 检查链接类型，优先使用直接音频流链接
if (playUrl.contains('ws.stream.qqmusic.qq.com')) {
  print('⚠️ [Play] 检测到QQ音乐链接，尝试获取直接音频流...');
  
  // 尝试使用lx-custom-source.js获取直接的音频流链接
  try {
    final directStreamUrl = await _getDirectStreamViaLxScript(item);
    if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
      print('✅ [Play] 通过LX脚本获取到直接音频流链接: $directStreamUrl');
      await _playDirectStream(directStreamUrl, selectedDeviceId, item, ref);
      return;
    }
  } catch (e) {
    print('⚠️ [Play] 获取直接音频流失败: $e，使用原始链接');
  }
}
```

## 🧪 **测试验证**

### **测试步骤**

1. **确保JS文件已添加**到assets目录
2. **更新pubspec.yaml**包含JS文件
3. **重新构建应用**
4. **搜索QQ音乐歌曲**
5. **点击播放**
6. **观察控制台日志**

### **预期结果**

如果集成成功，应该看到：

```
⚠️ [Play] 检测到QQ音乐链接，尝试获取直接音频流...
✅ [Play] 通过JS源获取到链接: https://example.com/song.mp3
✅ [Play] 确认是直接音频流链接
✅ [Play] 通过LX脚本获取到直接音频流链接: https://example.com/song.mp3
🎵 [Play] 准备调用 playUrl 接口...
✅ [Play] 直接播放请求成功
```

## 🔧 **配置说明**

### **lx-custom-source.js配置**

```javascript
// 服务端地址
const API_URL = 'http://43.143.63.234:9763'
// 服务端配置的请求key
const API_KEY = '3.141592653'

// 音质配置
const MUSIC_QUALITY = {
  kw: ['128k'],
  kg: ['128k'],
  tx: ['128k', '320k', 'flac', 'flac24bit'], // QQ音乐支持多种音质
  wy: ['128k'],
  mg: ['128k'],
}
```

### **平台映射**

- **qq/tencent** → **tx** (QQ音乐)
- **netease/163** → **wy** (网易云)
- **kuwo** → **kw** (酷我)
- **kugou** → **kg** (酷狗)
- **migu** → **mg** (咪咕)

## 🚀 **优势**

1. **直接音频流**：获取设备可以直接播放的音频链接
2. **多平台支持**：支持QQ音乐、网易云、酷狗等主流平台
3. **多音质选择**：QQ音乐支持从128k到无损音质
4. **稳定可靠**：使用专业的音乐API服务器

## 📝 **注意事项**

1. **网络连接**：确保能够访问API服务器
2. **API限制**：注意API的请求频率限制
3. **音质选择**：根据网络情况选择合适的音质
4. **错误处理**：做好网络异常和API错误的处理

## 🔄 **下一步**

1. **测试集成效果**
2. **优化错误处理**
3. **添加更多平台支持**
4. **优化用户体验**

