package app.meowoo.android.ui

import android.content.Intent
import android.provider.OpenableColumns
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.input.InputMode
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInputModeManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.meowoo.android.MeowooViewModel
import app.meowoo.android.BuildConfig
import app.meowoo.android.R
import app.meowoo.android.model.DeviceMode
import app.meowoo.android.model.SourceStatus
import app.meowoo.android.model.Sources
import app.meowoo.android.model.VideoEntry

private val destinations = listOf("发现", "片库", "内容源", "设置")

@Composable
fun MeowooApp(model: MeowooViewModel, mode: DeviceMode) {
    val context = LocalContext.current
    val inputMode = LocalInputModeManager.current.inputMode
    var destination by rememberSaveable { mutableIntStateOf(0) }
    var showUrl by rememberSaveable { mutableStateOf(false) }
    val navigationFocus = remember { List(destinations.size) { FocusRequester() } }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            runCatching { context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            val name = runCatching {
                context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(0) else null
                }
            }.getOrNull() ?: "本地视频"
            model.openUri(uri.toString(), name)
        }
    }
    val openFile: () -> Unit = {
        runCatching { picker.launch(arrayOf("video/*")) }
            .onFailure { model.showMessage("此设备没有文件选择器，可使用 HTTPS 播放地址") }
    }

    val active = model.activeVideo
    if (active != null) {
        PlaybackScreen(active, mode, model::updateProgress, model::closePlayer)
        return
    }
    BackHandler(destination != 0) { destination = 0 }
    // Touch navigation never moves focus by itself; remote input restores the selected tab.
    LaunchedEffect(mode, active, inputMode) {
        if (mode == DeviceMode.TV && inputMode == InputMode.Keyboard && !showUrl && model.message == null) {
            navigationFocus[destination].requestFocus()
        }
    }

    Surface(Modifier.fillMaxSize(), color = Canvas) {
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            Row(Modifier.weight(1f)) {
                if (mode != DeviceMode.PHONE) Column(
                    Modifier.width(if (mode == DeviceMode.TV) 180.dp else 156.dp).fillMaxHeight().padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Brand(compact = true)
                    Spacer(Modifier.height(24.dp))
                    destinations.forEachIndexed { index, label ->
                        ActionButton(label, { destination = index },
                            Modifier.fillMaxWidth().focusRequester(navigationFocus[index]), destination == index)
                    }
                    Spacer(Modifier.weight(1f))
                    Text(if (mode == DeviceMode.TV) "TV · 遥控 / 触屏" else "平板 · 横屏模式", color = Muted, fontSize = 12.sp)
                }
                Box(Modifier.weight(1f).fillMaxHeight()) {
                    when (destination) {
                        0 -> Discover(model.visibleHistory, mode, openFile, { showUrl = true }, model::play, { destination = 2 })
                        1 -> Library(model.visibleHistory, mode, model::play, openFile)
                        2 -> SourceScreen(model.nsfwEnabled)
                        else -> SettingsScreen(model, mode)
                    }
                }
            }
            if (mode == DeviceMode.PHONE) Row(
                Modifier.fillMaxWidth().background(Panel).padding(horizontal = 8.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                destinations.forEachIndexed { index, label -> ActionButton(label, { destination = index }, Modifier.weight(1f), destination == index) }
            }
        }
    }
    if (showUrl) UrlDialog(onClose = { showUrl = false }, onOpen = { if (model.openUrl(it)) showUrl = false })
    model.message?.let { message ->
        AlertDialog(onDismissRequest = model::dismissMessage, title = { Text("提示") }, text = { Text(message) },
            confirmButton = { ActionButton("知道了", model::dismissMessage) })
    }
}

@Composable
private fun Brand(compact: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Image(painterResource(R.drawable.mascot), "Meowoo 喵呜", Modifier.size(if (compact) 38.dp else 46.dp).clip(RoundedCornerShape(14.dp)))
        Column {
            Text("Meowoo", color = Sky, fontSize = if (compact) 18.sp else 24.sp, fontWeight = FontWeight.Bold)
            if (!compact) Text("喵呜 · 把喜欢的留在身边", color = Muted, fontSize = 12.sp)
        }
    }
}

@Composable
private fun Discover(history: List<VideoEntry>, mode: DeviceMode, openFile: () -> Unit, openUrl: () -> Unit, play: (VideoEntry) -> Unit, sources: () -> Unit) {
    LazyColumn(contentPadding = PaddingValues(if (mode == DeviceMode.TV) 32.dp else 24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        item { Brand() }
        item {
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp))
                .background(Brush.horizontalGradient(listOf(Panel, androidx.compose.ui.graphics.Color(0xFF173F4B)))).padding(24.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("今晚，看点喜欢的。", fontSize = if (mode == DeviceMode.PHONE) 26.sp else 34.sp, fontWeight = FontWeight.Bold)
                    Text("番剧 · 剧集 · 电影 · 综艺 · 短剧", color = Mint, fontSize = 14.sp)
                    Text("先从你的视频开始，观看进度会为你保留。", color = Muted, fontSize = 14.sp)
                    if (mode == DeviceMode.PHONE) Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        ActionButton("打开本地视频", openFile)
                        ActionButton("输入播放地址", openUrl)
                    } else Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        ActionButton("打开本地视频", openFile)
                        ActionButton("输入播放地址", openUrl)
                    }
                }
                if (mode != DeviceMode.PHONE) Image(painterResource(R.drawable.mascot), null,
                    Modifier.padding(start = 24.dp).size(if (mode == DeviceMode.TV) 180.dp else 136.dp).clip(RoundedCornerShape(28.dp)))
            }
        }
        item { Text("继续观看", fontSize = 22.sp, fontWeight = FontWeight.Bold) }
        if (history.isEmpty()) item { InfoPanel("给片库添上第一部作品", "打开本地文件或 HTTPS 视频地址，即可开始观看。") }
        items(history.take(4), key = { it.key }) { VideoRow(it, play) }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                InfoPanel("更多内容，陆续接入", "红果与其他在线内容源正在规划中。当前版本不会展示虚构片单。")
                ActionButton("管理内容源", sources)
            }
        }
    }
}

@Composable
private fun Library(history: List<VideoEntry>, mode: DeviceMode, play: (VideoEntry) -> Unit, openFile: () -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    val filtered = history.filter { it.title.contains(query, ignoreCase = true) }
    LazyColumn(contentPadding = PaddingValues(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item { Text("我的片库", fontSize = 28.sp, fontWeight = FontWeight.Bold) }
        item { OutlinedTextField(query, { query = it }, label = { Text("搜索已观看的视频") }, singleLine = true, modifier = Modifier.fillMaxWidth()) }
        if (filtered.isEmpty()) item { InfoPanel(if (query.isBlank()) "片库还空着" else "没有匹配的视频", "本地文件和播放地址的观看记录会保存在这里。") }
        items(filtered, key = { it.key }) { VideoRow(it, play) }
        item { ActionButton("打开本地视频", openFile) }
    }
}

@Composable
private fun VideoRow(entry: VideoEntry, play: (VideoEntry) -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Panel).padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(entry.title, maxLines = 2, fontWeight = FontWeight.SemiBold)
        Text("已观看 ${entry.positionMs / 60_000} 分钟" + if (entry.durationMs > 0) " · 共 ${entry.durationMs / 60_000} 分钟" else "", color = Muted, fontSize = 13.sp)
        ActionButton("继续观看", { play(entry) })
    }
}

@Composable
private fun SourceScreen(nsfw: Boolean) {
    LazyColumn(contentPadding = PaddingValues(24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        item { Text("内容源", fontSize = 28.sp, fontWeight = FontWeight.Bold) }
        item { Text("只显示当前内容偏好允许的来源", color = Muted) }
        items(Sources.visible(nsfw), key = { it.id }) { source ->
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Panel).padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(source.title + if (source.nsfw) " · 18+" else "", fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                Text(source.description, color = Muted)
                Text(if (source.status == SourceStatus.AVAILABLE) "已可使用" else "尚未接入", color = if (source.status == SourceStatus.AVAILABLE) Mint else Muted)
            }
        }
    }
}

@Composable
private fun SettingsScreen(model: MeowooViewModel, mode: DeviceMode) {
    var confirmClear by remember { mutableStateOf(false) }
    LazyColumn(contentPadding = PaddingValues(24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        item { Text("设置", fontSize = 28.sp, fontWeight = FontWeight.Bold) }
        item {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Panel).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("内容偏好", fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                Text("NSFW · 18+ 内容", color = Mint)
                Text("默认关闭，仅适用于年满 18 周岁的用户。关闭后隐藏相关来源及记录，本地记录会保留。", color = Muted)
                ActionButton(if (model.nsfwEnabled) "已开启 · 点击关闭" else "已关闭 · 点击开启", { model.setNsfw(!model.nsfwEnabled) },
                    modifier = Modifier.semantics {
                        role = Role.Switch
                        toggleableState = if (model.nsfwEnabled) ToggleableState.On else ToggleableState.Off
                        stateDescription = if (model.nsfwEnabled) "NSFW 已开启" else "NSFW 已关闭"
                    }, selected = model.nsfwEnabled)
                if (model.nsfwEnabled) Text("分级范围：里番、情色、成人电影、AV 等。黄果尚待迁移，开启开关不会自动新增内容源。", color = Muted, fontSize = 13.sp)
            }
        }
        item { InfoPanel("此设备", when (mode) { DeviceMode.PHONE -> "手机 · 竖屏触控"; DeviceMode.TABLET -> "平板 · 横屏触控"; DeviceMode.TV -> "电视 · 横屏遥控与触屏" }) }
        item { ActionButton("清空观看历史", { confirmClear = true }) }
        item { Text("Meowoo 喵呜 ${BuildConfig.VERSION_NAME} · 本地记录，不上传", color = Muted, fontSize = 13.sp) }
    }
    if (confirmClear) AlertDialog(onDismissRequest = { confirmClear = false },
        title = { Text("清空观看历史？") }, text = { Text("将清除所有来源的观看记录，视频文件不会删除。") },
        confirmButton = { ActionButton("清空", { model.clearHistory(); confirmClear = false }) },
        dismissButton = { ActionButton("取消", { confirmClear = false }) })
}

@Composable
private fun InfoPanel(title: String, body: String) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Panel).padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, fontWeight = FontWeight.SemiBold)
        Text(body, color = Muted, fontSize = 14.sp)
    }
}

@Composable
private fun UrlDialog(onClose: () -> Unit, onOpen: (String) -> Unit) {
    var value by rememberSaveable { mutableStateOf("") }
    AlertDialog(onDismissRequest = onClose, title = { Text("输入播放地址") },
        text = { OutlinedTextField(value, { value = it }, label = { Text("HTTPS 视频 / HLS 地址") }, singleLine = true, modifier = Modifier.fillMaxWidth()) },
        confirmButton = { ActionButton("播放", { onOpen(value) }) },
        dismissButton = { ActionButton("取消", onClose) })
}
