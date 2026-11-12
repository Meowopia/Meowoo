# Meowoo · 原生 Android 技术交接文档

更新时间：2026-11-11。本文依据当前工作区代码编写，面向接手开发的人员或代码助手。

工作区已于 2026-11-12 确认改名为 `Meowoo`；原生工程位于工作区下的 `meowoo-android`。上传仓库时以原生工程为仓库根目录。换机器克隆后，请配置本机 `local.properties`，不要沿用其他机器的 SDK 绝对路径。

本文范围是通用内容源框架、普通影视或自有媒体服务、已有播放器对接、分级与隐私管理。示例使用离线测试数据，不含特定成人站点的接口、采集或解密接入流程。本文是待实施设计，不代表这些功能已经完成。

## 1. 产品与开发约束

- 软件名称：Meowoo，中文名称：喵呜。
- 内容类型：番剧、电视剧、电影、综艺、短剧，以及用户自己的视频。
- 首阶段平台：Android 手机竖屏、Android 平板横屏、Android TV 横屏；TV 必须同时支持遥控器和触屏。
- 视觉沿用蓝、绿、白与现有头像，避免黄色、橙色。
- 原生 Kotlin + Jetpack Compose + Media3；已有播放器继续复用。
- 保持轻量：第一阶段使用编译进应用的 Kotlin 内容源实现，不引入脚本运行时、内置服务器或额外软件解码引擎。
- 业务代码由 handheld 与 tv 共享，仅在布局、焦点和设备入口上区别处理。
- 读取并保留现有未提交修改；不要重建整个工程或覆盖相邻的旧项目。

## 2. 当前已实现与未实现

| 项目 | 代码现状 | 验证边界 |
| --- | --- | --- |
| 手机、平板、TV 入口 | 两个 flavor，按设备选择布局 | 已有构建记录，未完成真机布局验收 |
| 原生播放器 | ExoPlayer + PlayerView，本地 URI、HTTPS 视频、HLS | 已构建，未完成真机解码和网络播放验收 |
| 播放进度 | 播放中每 5 秒保存，退后台暂停并保存，退出释放 | 核心历史规则有单元测试 |
| TV 双输入 | 标准 Button 同时处理触摸和 D-pad，触摸播放返回入口 | UI 测试已编译，尚未执行 |
| 内容源列表 | 静态 Source 元数据，在线来源仍为 PLANNED | 不是可用的在线内容源实现 |
| 内容分级 | 默认关闭 NSFW；来源与条目过滤；关闭时退出受限播放 | 尚无网络请求，因此没有完整的网络取消和迟到响应隔离 |
| 观看历史 | SharedPreferences JSON，最多 60 条 | 当前按来源与条目 ID 去重，尚无独立分集结构 |
| 搜索 | 仅搜索本地观看记录标题 | 尚无在线搜索 |
| 在线详情、选集、地址解析 | 未实现 | 不应仅修改 AVAILABLE 状态来宣称接入完成 |
| 登录、下载、云同步 | 未实现 | 不属于本次通用内容源首阶段范围 |

历史验证结果见 README。构建成功、测试 APK 编译成功均不能替代真机执行。

## 3. 现有代码定位

路径均相对于本文件所在的 `meowoo-android` 目录。

| 文件 | 职责及接手注意事项 |
| --- | --- |
| `app/src/main/java/app/meowoo/android/MainActivity.kt` | 设备模式、方向请求、Compose 入口 |
| `app/src/main/java/app/meowoo/android/MeowooViewModel.kt` | 设置、历史、activeVideo、本地与地址播放；目前没有在线仓库 |
| `app/src/main/java/app/meowoo/android/model/Library.kt` | Source、VideoEntry、可见性、历史去重和续播计算 |
| `app/src/main/java/app/meowoo/android/data/LibraryStore.kt` | `meowoo_library_v1` 偏好设置与 JSON 历史序列化 |
| `app/src/main/java/app/meowoo/android/ui/MeowooApp.kt` | 发现、片库、内容源、设置与地址弹窗；SourceScreen 目前为静态列表 |
| `app/src/main/java/app/meowoo/android/ui/PlaybackScreen.kt` | 已有播放引擎、生命周期、错误重试、TV 分层返回 |
| `app/src/main/java/app/meowoo/android/ui/Theme.kt` | 蓝绿主题 |
| `app/src/handheld/java/app/meowoo/android/ui/DeviceControls.kt` | 手机、平板按钮 |
| `app/src/tv/java/app/meowoo/android/ui/DeviceControls.kt` | TV 触摸和遥控共用按钮、焦点视觉 |
| `app/src/test/java/app/meowoo/android/model/LibraryTest.kt` | 现有 6 个核心测试 |
| `app/src/androidTest/java/app/meowoo/android/NavigationTest.kt` | 导航和分级开关 UI 测试 |
| `app/src/androidTest/java/app/meowoo/android/DualInputTest.kt` | 触摸、遥控确认与播放返回入口测试 |

现有 `play(entry)` 直接使用 `entry.uri`。接入在线来源后应新增单独的在线播放入口，由它解析媒体描述后再进入播放器，保留原有本地文件路径。

## 4. 建议的代码组织

以下目录与类型是建议新增项，尚未创建：

```text
app/src/main/java/app/meowoo/android/
  source/
    ContentSource.kt          内容源能力契约
    SourceModels.kt           卡片、详情、分页与播放描述
    SourceRegistry.kt         ID 到实现的映射
    SourceRepository.kt       统一查询、分级检查与错误转换
    SourceAccessPolicy.kt     来源启用状态与内容分级判断
  data/
    HistoryMigration.kt      历史记录兼容迁移
  ui/source/
    SourceBrowseScreen.kt    列表、刷新与分页
    SourceDetailScreen.kt    详情和选集
    SourceSearchScreen.kt    单来源搜索
    SourceViewModel.kt       查询状态、任务取消与迟到结果隔离
```

先保持单 app 模块；通过构造函数传入 Registry、Repository、时钟及调度器，便于测试。现阶段不必增加大型依赖注入框架或拆出大量 Gradle 模块。

## 5. 通用数据与接口契约

先定义能力，再写页面。不要让页面依赖某个服务的原始 JSON 字段。

| 建议类型 | 必要信息 | 约束 |
| --- | --- | --- |
| `SourceDescriptor` | id、name、description、capabilities、默认分级、可用状态 | ID 稳定，不随展示名称变化；启用状态与安装状态分开 |
| `MediaRef` | sourceId、mediaId | 用结构化键，避免简单拼接 ID 的分隔符冲突 |
| `MediaCard` | ref、title、cover、kind、分级、更新说明 | 不用观看记录对象充当片单对象 |
| `MediaDetail` | card、简介、episodes | 详情不等同于已经解析好的播放链接 |
| `Episode` | id、标题、顺序、可播放状态 | ID 是来源内部稳定值，不假设从 1 连续递增 |
| `Page<T>` | items、nextCursor | cursor 是不透明字符串；页码源由适配器自行转换 |
| `PlaybackDescriptor` | HTTPS URI、可选 MIME、必要请求配置、可选失效时间 | 只在当前播放会话内持有，不作为历史记录主键 |
| `SourceCapabilities` | browse、search、detail、play | 不支持的操作不显示入口，防止点击后才发现不存在 |

契约草图如下；这是设计示例，需要配套类型、实现与测试，不是可直接粘贴即完成接入的代码：

```kotlin
interface ContentSource {
    val descriptor: SourceDescriptor
    suspend fun browse(cursor: String?): Page<MediaCard>
    suspend fun search(query: String, cursor: String?): Page<MediaCard>
    suspend fun detail(mediaId: String): MediaDetail
    suspend fun resolvePlayback(mediaId: String, episodeId: String): PlaybackDescriptor
}
```

第一版限定单来源搜索。聚合搜索以后再做，避免当前阶段同时引入跨来源超时、排名和部分结果合并。

来源适配器只负责协议与数据映射，不持有 Activity、Compose 状态或播放器。未知来源必须拒绝解析；仅有静态元数据而没有注册实现的来源仍然标为未接入。

## 6. Repository、状态与异步操作

### 6.1 请求边界

1. 请求开始前读取来源启用状态与分级许可。
2. 在可取消的后台任务里读取数据；解析层不触碰 Compose UI。
3. 收到结果后再次核对许可和请求编号。
4. 只允许当前页面的当前请求更新状态。
5. 网络库应支持取消底层请求；只取消协程但让阻塞 IO 一直运行不算完整实现。

列表至少区分：首次加载、数据、空结果、首次失败、加载下一页、下一页失败、已到底。分页失败保留已经加载的内容，重试只重试该页；刷新成功再替换旧列表。

### 6.2 避免响应覆盖

- 每次更换关键词、来源、分级策略或退出来源页，都使该查询的 generation 失效。
- 取消旧任务后也要比对 generation；不能假设所有网络请求都会及时响应取消。
- 快速输入 A → AB → ABC，最终只显示 ABC 的结果。
- 相同 cursor 的下一页不能并发提交；结果按来源与媒体 ID 去重。
- 搜索支持键盘搜索操作和显式搜索按钮；可在此基础上加入约 350ms 防抖，使用可控调度器测试。
- 重新进入页面可保留查询、列表位置和选中条目；不要让每次重组触发重新请求。

### 6.3 失败处理

区分断网、超时、认证要求、权限不足、限流、服务异常、响应格式变化和条目失效。页面显示可理解的提示与重试入口，不显示原始响应正文、令牌或带凭据的 URL。

幂等读取可做有上限的退避重试；取消、认证失败和解析失败不自动重试。限流尊重服务提供的等待时间。不要给所有请求套无限重试。

## 7. 接入已有 Media3 播放器

正常流程：内容源列表 → 详情 → 选择集数 → Repository 解析播放描述 → 建立播放会话 → 现有 PlaybackScreen。

- 保留本地 `content://` 文件播放和直接 HTTPS 地址播放，两者不要求在线内容源。
- 在线历史保存稳定的媒体与分集标识。再次播放时重新解析地址；不要永久重用可能过期的 URL。
- 将临时媒体描述与持久化历史拆开，避免把请求头、访问令牌和签名地址写进 SharedPreferences。
- 只有服务协议确实要求时才配置额外请求头；按服务的目标主机范围应用，不要把 API 凭据默认发送给所有 CDN、重定向目标或媒体分片。
- 如需自定义数据源，保留本地 URI 的数据源能力，不把整个播放器换成仅支持 HTTP 的实现。
- MIME 仅在已知且需要时显式设置；不能假定每个网络地址都是 HLS。
- 保留音频焦点、拔出耳机处理、后台暂停、释放播放器、定时保存以及 TV 输入切换行为。

特别注意当前代码的 `remember(entry.key)`：同一条目刷新播放地址时，key 不变可能使旧 MediaItem 继续使用。新增播放会话 ID 或显式更新 MediaItem，并保证普通进度更新、触摸与遥控切换不会重建播放器。

如果将来实现地址失效后的重新解析，要限制自动恢复次数，保留实际播放位置和暂停状态；不能每遇到错误就无上限重新请求。离开页面或分级许可撤销后，迟到的解析结果不得开启播放器。

第一阶段可使用明确的选集按钮。自动下一集放在后续步骤，并测试季末、缺集、不可播放条目和重复结束回调。

## 8. 历史记录与数据迁移

当前历史最多 60 条，键为 `sourceId:id`。增加剧集后建议用结构化键 `sourceId + mediaId + episodeId`，三个字段分别存储和比较，不依赖不受控分隔符拼接。

建议把持久化历史与播放会话分为两个类型：

- 历史：来源、媒体 ID、分集 ID、标题、分级、位置、时长、更新时间；本地条目额外保存本地 URI。
- 会话：历史标识、临时 PlaybackDescriptor、当前起播位置、独立 sessionId。

迁移要求：

1. 增加 schemaVersion，读取旧 JSON 时为缺失的可选字段提供兼容默认值。
2. 原有本地 URI、标题与进度完整保留，不因新增来源丢失历史。
3. 逐条跳过损坏记录，单条损坏不能清空所有记录。
4. 写入新格式成功后再标记迁移完成；迁移重复执行结果一致。
5. 来源未知、停用或不满足当前分级时隐藏记录，不能因此自动删除。
6. 保留现有临近结束从头播放和未知时长续播规则，新增分集去重测试。

第一阶段仍可保留 SharedPreferences，避免为少量历史引入数据库迁移成本。需要大量收藏、复杂筛选或下载任务时，再独立评估持久化方案。

## 9. 分级与隐私隔离

NSFW 开关作为已有的用户内容偏好保留，默认关闭；它不是完整的年龄验证或家长控制机制。

分级判断集中在一个策略入口，同时检查来源级别和条目级别；混合来源不能只凭来源标记放行全部条目。来源声明优先取较严格级别。分级未知的数据采用明确的保守规则，不默认为适合所有用户。

关闭后应在同一轮状态更新中：

1. 使正在进行的受限查询和解析 generation 失效，并取消底层任务。
2. 关闭受限详情、选集和播放会话，停止声音并释放媒体请求。
3. 清除受限页面的内存结果与图片引用，返回可见页面。
4. 对发现页、搜索、历史、收藏及将来的通知统一应用策略。
5. 保留原有历史的存储语义：默认只隐藏，清除需使用明确的清空操作。

图片缓存按来源和分级隔离；第一阶段可只做有容量上限的内存缓存，不默认写入共享磁盘缓存。关闭分级后清除对应内存缓存，迟到的图片下载也不得重新入缓存。

不在日志中输出搜索词、片名、令牌和完整媒体地址。当前应用没有后台播放和媒体通知，不要为了接入内容源擅自增加会暴露内容标题的后台服务。

## 10. 页面与双输入验收要求

### 内容源、列表、详情

- SourceScreen 对已注册且可用的来源显示进入按钮；计划中的来源显示明确状态。
- 首页保留本地视频与 HTTPS 输入入口；来源页承接在线浏览。
- 手机优先纵向列表或紧凑卡片；平板和 TV 使用适合宽屏的布局，不复制三套业务代码。
- 详情展示标题、简介、分集和返回入口；简介较长时仍能到达选集。
- 加载状态、空结果、错误与重试都必须可被遥控器访问。
- 封面失败显示占位，不阻塞标题、选集与播放操作。

### TV 遥控与触屏

- 继续使用现有 ActionButton 的单一点击处理，避免手势与按键各执行一次造成双击。
- 触摸区域至少沿用当前 48dp 高度要求；触屏能完成搜索、选集、播放和返回，不依赖硬件返回键。
- 有可见焦点；D-pad 能遍历列表、选集、分页和重试按钮。
- 从详情返回恢复到原卡片和列表位置；刷新删除该卡片时给出合理焦点回退。
- 触摸操作不强制移动键盘焦点；恢复遥控后有明确焦点；焦点变化不重建播放会话。
- 返回顺序考虑弹窗 → 播放控制层 → 播放页 → 详情 → 列表 → 应用导航，不让主导航 BackHandler 抢先截获子页返回。

## 11. 推荐实施顺序与交付条件

| 阶段 | 工作 | 完成条件 |
| --- | --- | --- |
| A | 定义模型、注册表、策略与离线测试来源 | 不联网即可覆盖分页、详情、多集与错误状态 |
| B | 来源浏览、单来源搜索、详情与选集 | 手机与 TV 能通过测试数据完成导航，不显示伪造的线上可用状态 |
| C | 播放会话及历史迁移 | 自有测试媒体能进入现有播放器，本地视频功能无回归 |
| D | 请求取消、分级撤销、图片缓存与失败处理 | 迟到结果不会恢复被隐藏内容或触发播放 |
| E | 双输入与真机验收 | 手机、平板、TV 分别记录设备和结果；未验证项明确列出 |

离线测试来源只在 debug/test 可用，不混入正式来源列表。第一阶段不加入账号同步、广告处理、下载、动态插件和脚本执行，以免扩大改动范围。

## 12. 必须补充的测试

测试应验证行为，不只是镜像实现。所有夹具使用中性标题、测试域名和自有媒体。

| 场景 | 预期结果 |
| --- | --- |
| 来源未知、未启用或能力缺失 | 拒绝调用，并给出适当 UI 状态 |
| 列表和下一页、重复 ID、空页、重复 cursor | 不重复、不死循环、不丢失旧页 |
| 连续搜索且旧响应最后返回 | 只显示最新关键词结果 |
| 请求中关闭分级开关 | 旧结果不显示、不缓存、不触发播放 |
| 播放解析中退出详情 | 即使解析完成，也不重新打开播放器 |
| 相同来源同一影片的不同分集 | 历史分别保存，无覆盖 |
| 不同来源使用相同媒体 ID | 无历史串用、无错误续播 |
| 旧 JSON 记录缺少新增字段 | 本地 URI 和位置保留 |
| 相同条目换新播放描述 | 正确更新 MediaItem 并保留恢复位置 |
| UI 进度变化、触屏与遥控交替 | 播放会话不重复创建，按钮每次只触发一次 |
| 本地权限撤销、网络失败、坏响应 | 可恢复错误，不崩溃、不打印敏感数据 |
| 分级关闭后播放器销毁回调到达 | 不恢复 activeVideo，不违反历史保留策略 |

用可控的假时钟和假调度器验证防抖、取消及迟到响应；不要依靠真实网络和 sleep 验证竞争条件。对 HTTP 行为使用测试服务或 mock transport。

## 13. 构建、验证与安装包

当前配置快照：AGP 9.0.1、Compose Compiler 2.2.10、Gradle 9.1.0、Media3 1.8.0、minSdk 23、compileSdk 36、targetSdk 35。这是项目现状，不是“最新版本”推荐。本次功能工作不必顺便升级全部依赖。

在本目录执行：

```powershell
# 构建两个调试包
.\build.ps1 -UseMirror

# 单元测试和静态检查
.\build.ps1 -Task Check -UseMirror

# 编译两种设备的 UI 测试包；编译成功不代表测试已执行
.\gradlew.bat :app:assembleHandheldDebugAndroidTest :app:assembleTvDebugAndroidTest

# 分别连接对应设备后执行，必要时用 ANDROID_SERIAL 指定目标设备
.\gradlew.bat :app:connectedHandheldDebugAndroidTest
.\gradlew.bat :app:connectedTvDebugAndroidTest
```

`-UseMirror` 仅适用于 build.ps1。直接运行 Gradle 且需要相同镜像时，加 `-I scripts/mirrors.init.gradle`。本机 `.local-tools` 与缓存存在时，脚本会优先使用；换机器需准备自己的 JDK、SDK 与 local.properties。

功能确实完成后再增加版本号。注意 tv flavor 当前覆盖了 defaultConfig 的版本号，不能只改 defaultConfig 就假定两个包都已升级。保持两个既有包名，以免失去覆盖安装和历史兼容。

输出 APK 在 `app/build/outputs/apk/handheld/debug/` 和 `app/build/outputs/apk/tv/debug/`。用于交付的副本可放在 `artifacts/`，应标明设备、版本及 debug/release，并校验签名与 SHA-256。正式发布使用用户自己的签名配置，不提交密钥。

最终报告至少包含：修改文件、已完成能力、实际运行的检查、未执行的真机项目、已知问题与安装包位置。未连接设备时必须明确写“未真机验证”，不要写“播放正常”。

## 14. 给接手开发者的任务说明

> 在现有 Meowoo Kotlin/Compose 工程中实施本文的通用内容源框架，先用中性离线数据完成模型、浏览、搜索、详情、选集与分级隔离，再用自有测试媒体验证既有 Media3 播放器。保留手机/平板/TV 两个 flavor、本地播放、历史兼容和遥控/触屏交替操作。区分已实现与设计建议，按阶段完成必要测试后交付。本文不提供任何特定成人站点的适配实现。
