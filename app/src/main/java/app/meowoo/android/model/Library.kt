package app.meowoo.android.model

import java.net.URI

enum class DeviceMode { PHONE, TABLET, TV }

fun deviceMode(isTv: Boolean, smallestWidthDp: Int): DeviceMode = when {
    isTv -> DeviceMode.TV
    smallestWidthDp >= 600 -> DeviceMode.TABLET
    else -> DeviceMode.PHONE
}

enum class SourceStatus { AVAILABLE, PLANNED }
data class Source(val id: String, val title: String, val description: String, val nsfw: Boolean, val status: SourceStatus)

object Sources {
    val all = listOf(
        Source("local", "我的视频", "本地文件与 HTTPS 播放地址", false, SourceStatus.AVAILABLE),
        Source("hongguo", "红果短剧", "短剧内容源 · 尚未接入", false, SourceStatus.PLANNED),
        Source("huangguo", "黄果", "18+ 内容源 · 尚待迁移", true, SourceStatus.PLANNED),
    )
    fun visible(nsfwEnabled: Boolean) = all.filter { !it.nsfw || nsfwEnabled }
    fun mayDisplay(sourceId: String, nsfwEnabled: Boolean): Boolean =
        all.any { it.id == sourceId && (!it.nsfw || nsfwEnabled) }
}

data class VideoEntry(
    val id: String,
    val sourceId: String,
    val title: String,
    val uri: String,
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val updatedAt: Long = 0,
    val nsfw: Boolean = false,
) {
    val key: String get() = "$sourceId:$id"
    fun visible(nsfwEnabled: Boolean) = Sources.mayDisplay(sourceId, nsfwEnabled) && (!nsfw || nsfwEnabled)
}

fun validatedPlaybackUrl(input: String): String? = runCatching {
    val value = input.trim()
    val uri = URI(value)
    value.takeIf { uri.scheme.equals("https", ignoreCase = true) && !uri.host.isNullOrBlank() && uri.userInfo == null }
}.getOrNull()

fun upsertHistory(history: List<VideoEntry>, entry: VideoEntry): List<VideoEntry> =
    (listOf(entry.copy(positionMs = entry.positionMs.coerceAtLeast(0), durationMs = entry.durationMs.coerceAtLeast(0))) +
        history.filterNot { it.key == entry.key }).take(60)

fun playbackStartPosition(positionMs: Long, durationMs: Long): Long =
    if (durationMs > 0 && positionMs >= durationMs - 3_000) 0 else positionMs.coerceAtLeast(0)
