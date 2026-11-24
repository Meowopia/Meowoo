<div align="center">

<img src="assets/brand/meowoo-logo-flat.png" alt="Meowoo 喵呜 Logo" width="160" />

<h1>Meowoo · 喵呜</h1>

<p><strong>把喜欢的故事，带到每一块屏幕。</strong></p>
<p>跨平台个人影音与阅读客户端 · 视频 / 漫画 / 轻小说</p>

<p>
<a href="https://meowoo.meowopia.com/">官网</a> ·
<a href="https://wiki.meowopia.com/meowoo/">Wiki</a> ·
<a href="#features">功能</a> ·
<a href="#platforms">平台</a> ·
<a href="#download">获取应用</a>
</p>

</div>

Meowoo（喵呜）新版基于 [Miru Alpha](https://github.com/miru-project/miru-alpha) 开发，使用 Flutter / Dart，并内置 [miru-core](https://github.com/miru-project/miru-core) 运行来源扩展和处理媒体请求。

> **开发预览**：新版尚未发布，当前公开代码仍为早期客户端。以下是新版的产品方向和验收状态；安装包、支持平台及使用说明以实际发布为准。

<a id="features"></a>

## 功能

| 功能 | 新版状态 |
| --- | --- |
| 视频播放、漫画和轻小说阅读 | 上游已有能力，Meowoo 待验收 |
| 来源扩展、搜索、详情和选集 | 上游已有能力，Meowoo 待验收；可用来源取决于具体扩展 |
| 本地历史、收藏和下载管理 | 上游已有能力，Meowoo 待验收 |
| 界面语言 | 本轮以简体中文和 English 为基础；可用语言以发布版本为准，更多语言按翻译和验收进度交付 |
| 私人媒体库、NAS 和更多来源适配 | 规划中 |
| OO 登录、TV 配对与跨设备云存档 | 尚未交付 |

应用不内置片库。界面语言和影片的字幕、音轨语言分别管理。

<a id="platforms"></a>

## 平台

| 平台 | Meowoo 新版进度 |
| --- | --- |
| Android 手机 / 平板 | 上游已有版本，待 Meowoo 验收 |
| Windows、Linux | 上游已有版本，待 Meowoo 验收 |
| iOS / iPadOS、macOS | 上游已有平台工程，尚未交付 |
| Android TV | 仍需独立适配与实机验收 |
| HarmonyOS NEXT | 规划中，须原生适配 |

Meowoo 当前不提供 Web 客户端。

<a id="download"></a>

## 获取应用

**Meowoo 新版暂无正式安装包。** 请关注 [Meowoo Releases](https://github.com/Meowopia/Meowoo/releases)。Miru Alpha 的安装包属于上游项目；此仓库早期代码的构建方式也不适用于新版。

## 反馈与致谢

欢迎通过 [GitHub Issues](https://github.com/Meowopia/Meowoo/issues) 提交建议或报告问题。反馈时请附版本、设备、系统和复现步骤，并从截图或日志中移除账号凭据与个人信息。

感谢 Miru Alpha 与 miru-core 提供新版基础，也感谢 [Animeko](https://github.com/open-ani/animeko)、[Kazumi](https://github.com/Predidit/Kazumi)、[AnimeFlow](https://github.com/openAnimeFlow/AnimeFlow)、[AniCh](https://github.com/Ls-Kr/AniCh) 和 [Izuko TV](https://github.com/GrahamZen/izuko-tv) 提供参考。新版客户端与内置核心分别保留上游 GPL-3.0 和 AGPL-3.0 许可；各第三方资源遵循各自许可。
