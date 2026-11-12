package app.meowoo.android.ui

import android.view.ViewGroup
import android.view.View
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.InputMode
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInputModeManager
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import app.meowoo.android.model.DeviceMode
import app.meowoo.android.model.VideoEntry
import kotlinx.coroutines.delay

@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
@Composable
fun PlaybackScreen(entry: VideoEntry, mode: DeviceMode, saveProgress: (VideoEntry, Long, Long) -> Unit, onClose: () -> Unit) {
    val context = LocalContext.current
    val inputMode = LocalInputModeManager.current.inputMode
    val lifecycleOwner = LocalLifecycleOwner.current
    val save by rememberUpdatedState(saveProgress)
    var error by remember(entry.key) { mutableStateOf<String?>(null) }
    var controlsVisible by remember(entry.key) { mutableStateOf(true) }
    val player = remember(entry.key) {
        ExoPlayer.Builder(context).build().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
            setHandleAudioBecomingNoisy(true)
            setMediaItem(MediaItem.fromUri(entry.uri))
            seekTo(entry.positionMs)
            prepare()
            playWhenReady = true
        }
    }
    val playerView = remember(player) {
        PlayerView(context).apply {
            this.player = player
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            useController = true
            controllerAutoShow = true
            controllerHideOnTouch = true
            setShowSubtitleButton(true)
            isFocusable = true
        }
    }
    fun record() = save(entry, player.currentPosition, player.duration.takeIf { it != C.TIME_UNSET } ?: 0)

    DisposableEffect(player, lifecycleOwner) {
        playerView.setControllerVisibilityListener(PlayerView.ControllerVisibilityListener { visibility ->
            controlsVisible = visibility == View.VISIBLE
        })
        val listener = object : Player.Listener {
            override fun onPlayerError(problem: PlaybackException) {
                error = "播放失败，请检查地址、文件权限或视频格式（${problem.errorCodeName}）"
            }
            override fun onIsPlayingChanged(isPlaying: Boolean) { playerView.keepScreenOn = isPlaying }
        }
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) { player.pause(); record() }
        }
        player.addListener(listener)
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            record()
            lifecycleOwner.lifecycle.removeObserver(observer)
            player.removeListener(listener)
            playerView.keepScreenOn = false
            playerView.setControllerVisibilityListener(null as PlayerView.ControllerVisibilityListener?)
            playerView.player = null
            player.release()
        }
    }
    LaunchedEffect(player, inputMode) {
        if (mode == DeviceMode.TV && inputMode == InputMode.Keyboard) playerView.requestFocus()
    }
    LaunchedEffect(player) {
        while (true) { delay(5_000); if (player.isPlaying) record() }
    }
    BackHandler {
        if (mode == DeviceMode.TV && playerView.isControllerFullyVisible) playerView.hideController()
        else onClose()
    }

    Column(Modifier.fillMaxSize().background(Color.Black).safeDrawingPadding()) {
        if (mode != DeviceMode.TV) Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ActionButton("返回", onClose)
            Text(entry.title, modifier = Modifier.weight(1f).padding(top = 16.dp), maxLines = 1, color = Color.White)
        }
        Box(Modifier.fillMaxWidth().weight(1f)) {
            AndroidView(factory = { playerView }, modifier = Modifier.fillMaxSize())
            if (mode == DeviceMode.TV && inputMode == InputMode.Touch && controlsVisible) {
                TvTouchPlaybackHeader(entry.title, onClose, Modifier.align(Alignment.TopStart))
            }
        }
        if (error != null) Column(Modifier.fillMaxWidth().background(Panel).padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(error!!, color = Color.White)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ActionButton("重试", { error = null; player.prepare(); player.play() })
                ActionButton("返回片库", onClose)
            }
        } else if (mode == DeviceMode.PHONE) {
            Column(Modifier.fillMaxWidth().background(Panel).padding(24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("正在播放", color = Mint)
                Text(entry.title, color = Color.White)
                Text("进度自动保存 · 返回后可继续观看", color = Muted)
            }
        }
    }
}

@Composable
internal fun TvTouchPlaybackHeader(title: String, onClose: () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.65f)).padding(horizontal = 20.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        ActionButton("返回片库", onClose)
        Text(title, modifier = Modifier.weight(1f), maxLines = 1, color = Color.White)
    }
}
