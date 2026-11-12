package app.meowoo.android

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import app.meowoo.android.data.LibraryStore
import app.meowoo.android.model.VideoEntry
import app.meowoo.android.model.playbackStartPosition
import app.meowoo.android.model.upsertHistory
import app.meowoo.android.model.validatedPlaybackUrl
import java.net.URI
import java.util.UUID

class MeowooViewModel(application: Application) : AndroidViewModel(application) {
    private val library = LibraryStore(application)
    var nsfwEnabled by mutableStateOf(library.nsfwEnabled)
        private set
    var history by mutableStateOf(library.readHistory())
        private set
    var activeVideo by mutableStateOf<VideoEntry?>(null)
        private set
    var message by mutableStateOf<String?>(null)
        private set

    val visibleHistory get() = history.filter { it.visible(nsfwEnabled) }

    fun setNsfw(value: Boolean) {
        nsfwEnabled = value
        library.nsfwEnabled = value
        if (activeVideo?.visible(value) == false) activeVideo = null
    }

    fun play(entry: VideoEntry) {
        if (!entry.visible(nsfwEnabled)) return
        activeVideo = entry.copy(positionMs = playbackStartPosition(entry.positionMs, entry.durationMs))
        updateProgress(activeVideo!!, activeVideo!!.positionMs, activeVideo!!.durationMs)
    }

    fun openUri(uri: String, title: String) {
        val existing = history.firstOrNull { it.sourceId == "local" && it.uri == uri }
        play(existing ?: VideoEntry(UUID.randomUUID().toString(), "local", title, uri))
    }

    fun openUrl(value: String): Boolean {
        val uri = validatedPlaybackUrl(value)
        if (uri == null) { message = "请输入有效的 HTTPS 视频地址"; return false }
        val title = runCatching { URI(uri).path.substringAfterLast('/').ifBlank { "网络视频" } }.getOrDefault("网络视频")
        openUri(uri, title)
        return true
    }

    fun updateProgress(entry: VideoEntry, position: Long, duration: Long) {
        // Removing history while a player is open is not offered; progress belongs to its source.
        history = upsertHistory(history, entry.copy(positionMs = position, durationMs = duration, updatedAt = System.currentTimeMillis()))
        library.saveHistory(history)
    }

    fun closePlayer() { activeVideo = null }
    fun clearHistory() { history = emptyList(); library.saveHistory(history) }
    fun showMessage(value: String) { message = value }
    fun dismissMessage() { message = null }
}
