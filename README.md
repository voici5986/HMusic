# HMusic - 智能音乐播放器 🎵

> 一款支持小米 AI 音箱的音乐播放器，**双模式支持**：xiaomusic 服务端模式 + 小米 IoT 直连模式

[![Release](https://img.shields.io/github/v/release/hpcll/HMusic?label=版本)](https://github.com/hpcll/HMusic/releases)

## 📱 下载安装

从 [Releases](https://github.com/hpcll/HMusic/releases) 下载最新版本：

| 平台 | 文件 | 说明 |
|------|------|------|
| 🤖 Android 通用版 | `HMusic-v2.2.0-android-universal.apk` | 推荐，兼容所有设备 |
| 🤖 Android arm64 | `HMusic-v2.2.0-android-arm64-v8a.apk` | 现代手机，体积更小 |
| 🤖 Android arm32 | `HMusic-v2.2.0-android-armeabi-v7a.apk` | 老旧设备 |
| 🍎 iOS | `HMusic-v2.2.0-ios-unsigned.ipa` | 需自签名安装 |

## 🎯 两种模式

| | 📱 直连模式 | 🖥️ xiaomusic 模式 |
|---|---|---|
| **适合人群** | 普通用户，开箱即用 | 有 NAS/服务器的用户 |
| **需要** | 小米账号 | 部署 [xiaomusic](https://github.com/hanxi/xiaomusic) |
| **功能** | 音乐搜索、播放、音量控制 | 完整功能（本地音乐库、播放列表、进度控制） |

## ⚡ 快速开始

### 直连模式（推荐新手）

1. 打开应用 → 选择 **直连模式**
2. 登录小米账号 → 选择音箱设备
3. 搜索音乐 → 播放！

> ⚠️ **移动数据用户**：需配置音频代理，详见 [代理部署指南](cloudflare-worker/README.md)

### xiaomusic 模式

1. 先部署 [xiaomusic 服务端](https://github.com/hanxi/xiaomusic)
2. 打开应用 → 选择 **xiaomusic 模式**
3. 输入服务器地址和认证信息

## 📚 文档

- [常见问题 FAQ](docs/FAQ.md)
- [代理部署指南](cloudflare-worker/README.md)
- [更新日志](CHANGELOG.md)
- [开发者文档](ARCHITECTURE.md)

---

## 🙏 致谢

感谢 [xiaomusic](https://github.com/hanxi/xiaomusic) 项目及其开发者 [@hanxi](https://github.com/hanxi)，HMusic 的 xiaomusic 模式基于该项目实现，直连模式的小米 IoT API 也参考了相关实现。

---

## ☕ 请作者喝杯咖啡

如果 HMusic 对你有帮助，欢迎请作者喝杯咖啡～ 你的支持是我持续开发的动力！

<p align="center">
  <img src="docs/donate/wechat.jpg" alt="微信赞赏码" width="250" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/donate/alipay.jpg" alt="支付宝收款码" width="250" />
</p>

<p align="center">
  <b>微信赞赏</b>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <b>支付宝</b>
</p>

---

## 📜 许可证

[AGPL-3.0](LICENSE) - 开源免费，商业使用需授权
