# Meowoo 喵呜 · Android

首版面向 Android 手机、平板与电视。原生 Kotlin + Jetpack Compose + Media3，不使用 WebView 播放，不内置服务器或额外软件解码引擎。沿用已选定的蓝绿白头像。

通用内容源开发与技术交接见 [Meowoo.md](Meowoo.md)，包含当前实现、待补充接口、播放器对接、历史迁移、双输入交互及验收要求。

工作区目录 `HG` 改名为 `Meowoo` 的辅助脚本为 [scripts/Rename-Workspace.ps1](scripts/Rename-Workspace.ps1)。需要先解除 Windows 对目录的占用；支持 `-WhatIf` 预览，成功后同步本机 SDK 路径。项目文档记录了当前改名状态。

## 安装包与设备

| 构建变体 | 设备 | 布局与交互 | 包名 |
| --- | --- | --- | --- |
| handheld | 手机 | 竖屏，底部导航，触控 | app.meowoo.android |
| handheld | 平板 | 横屏，侧栏导航，宽屏布局 | app.meowoo.android |
| tv | Android TV / Google TV / 触屏大屏 | 横屏，双启动入口，焦点高亮按钮，遥控器与触屏 | app.meowoo.android.tv |

最低 Android 6.0（API 23）。平板按系统 `smallestScreenWidthDp >= 600` 判定。Activity 请求手机竖屏、平板感应横屏；分屏、折叠屏或系统兼容模式可能覆盖方向请求，仍需真机验证。TV 0.1.1 同时提供普通 Launcher 与 Leanback 入口，两种硬件能力均非必需，不会排除无触屏电视或无 Leanback 的触屏大屏。

## 0.1.0 范围

- 发现页、可搜索的本地观看记录、内容源状态、设置。
- 系统文件选择器打开视频，不申请整个存储空间权限。
- 输入 HTTPS 视频/HLS 地址，通过 Media3 播放；具体格式、音视频编码与字幕支持依赖设备及 Media3，不保证任意网页链接都能播放。
- 每 5 秒保存正在播放的视频进度；退到后台暂停，退出播放释放播放器；临近结尾的记录从头播放。
- 默认关闭的 NSFW 设置保存在本机；来源和条目双重过滤，来源 + ID 隔离观看记录。关闭后退出不再允许显示的播放内容，记录保留。
- 黄果明确标为“尚待迁移”，红果标为“尚未接入”，未发起这些站点的请求。成人类别只表示分级范围，不表示新增站点。
- 两个包分别保存设置和观看历史；无账号同步、云上传、BT、下载管理或服务端转码。

本次未复制 Miru、Animeko 或 Izuko 的实现代码。TV 模块组织与遥控交互参考 [Izuko TV](https://github.com/GrahamZen/izuko-tv) 和 [Android Compose for TV](https://developer.android.com/training/tv/playback/compose)。已有 HGhub 保留在相邻目录，不作原地替换。

## 构建

使用 Android Studio 或 JDK 17+ 与 Gradle 9.1.0。JDK 25 从 Gradle 9.1 起可运行；工程使用 AGP 9.0.1 的内置 Kotlin，并配套 Compose Compiler 2.2.10。安装 Android SDK platform 36、build-tools 36.0.0 与 platform-tools。

在 `local.properties` 配置本机 SDK 路径（不提交此文件），或者设置 `ANDROID_HOME`。

```powershell
.\gradlew.bat :app:assembleHandheldDebug :app:assembleTvDebug
.\gradlew.bat :app:testHandheldDebugUnitTest :app:testTvDebugUnitTest :app:lintHandheldDebug :app:lintTvDebug
```

APK 输出在 `app/build/outputs/apk/handheld/debug/` 和 `app/build/outputs/apk/tv/debug/`。Debug 包用于验证，正式发行需要配置自己的签名后构建 release；release 已开启 R8 与资源裁剪。

Windows 也可运行 `./build.ps1`；首次构建网络不通时使用 `./build.ps1 -UseMirror`，仅本次构建通过阿里云镜像取依赖，不改变项目默认仓库。`./build.ps1 -Task Check -UseMirror` 执行单元测试与 lint。脚本优先使用本项目已准备的 `.local-tools` 工具与缓存，否则调用标准 Gradle Wrapper；不修改系统环境变量。工具和 SDK 不纳入 Git。

连接对应设备后运行 UI 测试：

```powershell
.\gradlew.bat :app:connectedHandheldDebugAndroidTest
# Android TV 设备单独执行：
.\gradlew.bat :app:connectedTvDebugAndroidTest
```

## 上机验收

- 手机竖屏 / 平板横屏 / 电视 Leanback 启动；系统栏与安全区不遮挡按钮。
- 本地 MP4 与可直连 HTTPS HLS 的起播、暂停、拖动、字幕、音轨、返回续播。
- 手机与平板切后台暂停、返回后手动继续，退出播放无声音残留。
- TV 方向键遍历导航和操作按钮，确认播放；播放器返回先收起控制层，再退出，返回主页后有可见焦点。
- TV 触摸导航按钮、滑动片库、输入地址、切换 NSFW；播放时轻触画面唤出控制栏，拖动进度，点击顶部“返回片库”。触屏与遥控器交替操作，每次确认只执行一次，切换输入方式不重建播放器。
- NSFW 开关重启后保持；关闭时黄果隐藏，红果和本地来源仍可见。
- 无文件选择器的电视可使用 HTTPS 地址；失效地址和被撤销文件权限给出播放错误。

尚未连接真机，UI 测试与以上播放验收不能用编译成功代替。

## 本次验证（2026-11-11）

- handheld、tv 调试 APK 均已构建，并通过 APK 签名校验。
- 6 个核心单元测试在两个构建变体各执行一次，共 12 项通过。
- 两个变体的 Android Lint 均为 0 错误，仍有非阻断警告（版本、图标形状、样式建议等）；未通过屏蔽检查或生成 baseline 绕过错误。
- 两个变体的 Android UI 测试 APK 已编译，因未连接设备而未执行。
- 已核对手机包为普通 Launcher 入口，电视包为 Leanback 入口且不要求触摸屏。
- 供安装验证的调试包位于 `artifacts/`；不是正式发行签名版本。尚未完成真机播放、资源占用与遥控体验验证。

## TV 0.1.1 双输入更新

TV 按钮使用同时支持触摸与键盘/D-pad 的 Compose Material3 Button，保留电视焦点描边与放大效果，触摸高度至少 48dp。播放器沿用 Media3 触摸控制栏，在触摸模式显示可点击的返回入口；遥控模式保留分层返回。输入切换只调整焦点，不重新创建播放会话。新增真实触摸事件、遥控确认与触屏返回入口的 UI 测试，需连接设备执行。

本次 TV/handheld 构建与两种 UI 测试包编译通过，TV 核心单元测试 6 项通过，TV lint 为 0 错误、7 项非阻断警告。已核对 TV 0.1.1 的双 Launcher 入口、硬件可选声明和 APK 签名；仍未连接设备执行触屏/遥控交互测试。新版安装包：`artifacts/Meowoo-0.1.1-android-tv-debug.apk`。
