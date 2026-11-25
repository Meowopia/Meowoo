# Meowoo 喵呜

Meowoo 是基于 Miru Alpha 的跨平台个人媒体客户端，用于播放视频、阅读漫画和小说，并管理收藏与历史。

## Android 手机首版

- Android 9 或更新版本，ARM64。
- 支持扩展源管理、少量公开演示内容、本地收藏和历史，以及基础 Jellyfin 接入。
- Android 平板和 TV、iOS/iPadOS、Windows、macOS、Linux、原生鸿蒙属于产品目标，不等同于本次交付。
- OO 登录、跨设备云存档和完整动态装扮暂未交付。

安装包与验收状态以 [GitHub Releases](https://github.com/Meowopia/Meowoo/releases) 为准。

## 源码与许可

客户端基于 [Miru Alpha](https://github.com/miru-project/miru-alpha)，内置 [Miru Core](https://github.com/miru-project/miru-core)。请参阅 [上游与许可说明](UPSTREAM.md)及 [项目许可证](LICENSE)。

源码检出时使用 `git submodule update --init --recursive` 初始化 Core。构建工具版本见 [toolchain lock](tool/meowoo/upstream.lock.json)。
