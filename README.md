<div align="center">

<img src="assets/brand/meowoo-logo-mono.png" alt="Meowoo 喵呜 Logo" width="200" />

<h1>Meowoo · 喵呜</h1>

<p><strong>把喜欢的故事，带到每一块屏幕。</strong></p>

<p>面向全平台的个人影音应用<br />
番剧 · 剧集 · 电影 · 综艺 · 短剧</p>

<p>
<img src="https://img.shields.io/badge/status-in_development-38BFA7?style=flat-square" alt="开发中" />
<img src="https://img.shields.io/badge/current_client-Android-438FD0?style=flat-square" alt="当前客户端：Android" />
<a href="https://github.com/Meowopia/Meowoo/stargazers"><img src="https://img.shields.io/github/stars/Meowopia/Meowoo?style=flat-square&color=38BFA7" alt="GitHub Stars" /></a>
</p>

<p>
<a href="#features">功能</a> ·
<a href="#platforms">平台</a> ·
<a href="#download">获取应用</a> ·
<a href="#roadmap">开发计划</a> ·
<a href="#references">参考项目</a>
</p>

</div>

Meowoo（喵呜）希望成为你的个人影音入口：打开本地视频，浏览喜欢的作品，在手机、平板和电视上继续观看。以蓝、绿、白为主色，兼顾触屏、遥控器与大屏浏览。

产品面向 Android、iOS / iPadOS、原生鸿蒙、Windows、macOS、Linux 和 Web。当前先提供 Android 客户端基础，逐步扩展自定义来源、网盘与 NAS、跨设备同步，以及漫画和轻小说阅读。

> **开发中**：目前没有正式发行安装包。下文区分公开源码已有能力、已实现待发布功能和开发计划；各平台与功能的可用性以实际版本为准。

<a id="features"></a>

## 功能

### 打开视频，接着上次看

当前公开源码已具备以下 Android 功能：

- **本地播放**：通过系统文件选择器打开视频。
- **网络播放**：输入可直接访问的 HTTPS 媒体地址，支持 MP4、HLS 等格式。
- **播放控制**：暂停、拖动进度，以及可用字幕与音轨的选择。
- **观看历史**：在本机保存观看记录和进度，方便继续播放。
- **适配不同屏幕**：手机、平板与 TV 布局；电视端兼顾遥控器、方向键与触屏。
- **内容偏好**：按本机设置过滤来源与历史，扩展内容显示默认关闭。

### 浏览、搜索与选集

以下能力**已实现，待发布**，尚未包含在当前公开源码或正式发行版中：

- 在线来源的分类浏览、搜索、分页、封面与作品详情。
- 在详情页选择播放线路和分集。
- 刷新失效播放地址、重试并保留观看进度。
- 改善界面重建后的播放恢复、本地文件授权与返回焦点。

<details>
<summary>查看已接入、待发布的在线来源</summary>

| 来源 | 内容范围 |
| --- | --- |
| 稀饭动漫 Next | 动漫浏览、搜索、详情与选集 |
| 红果短剧 | 官网目录与实际开放的剧集 |
| 非凡资源 | 影视、动漫、综艺与短剧 |
| 量子资源 | 影视、动漫、综艺与短剧 |
| 暴风资源 | 影视、动漫、综艺与短剧 |

具体目录、线路、更新与播放可用性取决于对应服务。红果接入范围仅包含官网开放内容。目前不同来源与线路分别保存观看进度；播放中跨来源换源仍在计划中。

</details>

<a id="platforms"></a>

## 平台

| 平台 | 当前进度 | 设备与操作 |
| --- | --- | --- |
| Android 手机 / 平板 | 已有客户端基础 | 竖屏与横屏、触屏 |
| Android TV / 触屏大屏 | 已有客户端基础 | 遥控器、方向键、触屏 |
| iOS / iPadOS | 规划中 | 手机、平板 |
| HarmonyOS NEXT（原生鸿蒙） | 规划中 | 鸿蒙手机、平板 |
| Windows | 规划中 | 桌面、键鼠 |
| macOS | 规划中 | 桌面、键鼠 |
| Linux | 规划中 | 桌面、键鼠 |
| Web | 规划中 | 浏览器、响应式布局 |

Android 最低支持 **6.0（API 23）**。手机和平板使用 **handheld** 版本，电视使用 **tv** 版本。其余平台尚未提供客户端；原生鸿蒙作为独立平台适配。

<a id="download"></a>

## 获取应用

**目前暂无正式发行安装包。** 后续版本将发布在 [GitHub Releases](https://github.com/Meowopia/Meowoo/releases)。

现在可以[从源码构建 Android 客户端](#build)。安装后，在首页选择本地视频或输入 HTTPS 媒体直链，再从观看历史继续播放。

<a id="roadmap"></a>

## 开发计划

以下功能尚未完整交付：

- [ ] **自由选择来源** — 自定义播放源、配置导入导出、启停排序、连接测试与聚合搜索。
- [ ] **播放中换源** — 匹配同一作品与分集，切换来源或线路时保留播放位置。
- [ ] **追番与追剧** — 收藏、想看 / 在看 / 看完、更新提醒、自动下一集。
- [ ] **更多播放体验** — 手势操作、外挂字幕、弹幕、离线下载与投屏。
- [ ] **个人媒体库** — 网盘、WebDAV、SMB、NAS；飞牛文件共享与影视媒体库适配。
- [ ] **OO 账号与云存档** — 手机登录、TV 配对、跨设备进度、备份与恢复。
- [ ] **漫画与轻小说** — 章节、翻页、阅读排版、书签与阅读进度。
- [ ] **全平台客户端** — iOS / iPadOS、HarmonyOS NEXT、Windows、macOS、Linux 与 Web。
- [ ] **多语言界面** — 跟随系统、手动切换、本地化格式与从右向左布局。

### 多语言

计划覆盖以下 16 种语言，并逐步扩展：

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Русский · Deutsch · Français · Español · Português · Italiano · العربية · हिन्दी · Bahasa Indonesia · ไทย · Tiếng Việt

目前尚未提供多语言切换。语言包将随翻译与界面适配分批交付，界面语言与影片字幕、音轨语言分别管理。

## 常见问题

<details>
<summary>可以直接粘贴视频网站的网页地址吗？</summary>

当前网络播放入口接受可直接访问的 HTTPS 媒体地址，例如 MP4 文件或 HLS 播放列表。普通网页地址通常不能直接播放；在线来源浏览功能以安装版本为准。

</details>

<details>
<summary>历史记录会同步到其他设备吗？</summary>

当前公开版本将播放历史与设置保存在本机，手机 / 平板版与 TV 版分别保存。OO 账号与跨设备云存档尚未交付。

规划中的云存档用于同步记录与设置，默认不上传视频文件、本机文件访问权限或来源登录凭据。

</details>

<details>
<summary>现在能导入自定义源、连接 NAS 或飞牛吗？</summary>

这些能力仍在开发计划中。来源配置导入、WebDAV、SMB 与飞牛媒体库需要分别适配，不能将某一种协议接入视为全部服务均已支持。

</details>

<a id="build"></a>

## 从源码构建

当前 Android 客户端使用 **Kotlin · Jetpack Compose · Media3 ExoPlayer**。其他平台的构建说明将在对应客户端提供时补充。

<details>
<summary>Android 构建步骤</summary>

准备 JDK 17+、Android SDK 36，使用仓库内的 Gradle Wrapper。在 `local.properties` 配置 SDK 路径，或设置 `ANDROID_HOME`。

Windows：

```powershell
.\gradlew.bat :app:assembleHandheldDebug :app:assembleTvDebug
```

macOS / Linux：

```bash
bash ./gradlew :app:assembleHandheldDebug :app:assembleTvDebug
```

生成的 APK：

| 版本 | 输出目录 |
| --- | --- |
| 手机 / 平板 | `app/build/outputs/apk/handheld/debug/` |
| TV | `app/build/outputs/apk/tv/debug/` |

上述命令构建 Android 调试包。正式发行包需要独立签名。

</details>

## 参与项目

欢迎通过 [Issues](https://github.com/Meowopia/Meowoo/issues) 反馈问题、提出功能建议，也欢迎提交代码、改进文档和参与翻译。

反馈播放或界面问题时，请附上应用版本、设备与系统版本、复现步骤；日志和截图请先移除账号凭据及个人信息。

<a id="references"></a>

## 参考与致谢

感谢以下项目提供的设计与实现思路：

| 项目 | 参考方向 |
| --- | --- |
| [Miru](https://github.com/miru-project/miru-app) | 视频、漫画、小说的多来源与扩展组织 |
| [Animeko](https://github.com/open-ani/animeko) | 追番体验、来源选择与播放流程 |
| [Kazumi](https://github.com/Predidit/Kazumi) | 自定义规则、多源选择与跨设备同步 |
| [AnimeFlow](https://github.com/openAnimeFlow/AnimeFlow) | 来源配置、候选匹配与播放状态管理 |
| [AniCh](https://github.com/Sle2p/AniCh) | 多端媒体应用设计 |
| [Izuko TV](https://github.com/GrahamZen/izuko-tv) | 电视端浏览与交互 |

各项目的代码与美术资源遵循其各自授权。列为参考不代表 Meowoo 已具备全部对应功能，或兼容其规则与插件格式。
