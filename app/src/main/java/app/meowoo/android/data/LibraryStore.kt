package app.meowoo.android.data

import android.content.Context
import app.meowoo.android.model.VideoEntry
import org.json.JSONArray
import org.json.JSONObject

class LibraryStore(context: Context) {
    private val prefs = context.getSharedPreferences("meowoo_library_v1", Context.MODE_PRIVATE)
    var nsfwEnabled: Boolean
        get() = prefs.getBoolean("nsfw", false)
        set(value) { prefs.edit().putBoolean("nsfw", value).apply() }

    fun readHistory(): List<VideoEntry> = runCatching {
        val array = JSONArray(prefs.getString("history", "[]"))
        (0 until array.length()).mapNotNull { index ->
            runCatching {
                val row = array.getJSONObject(index)
                VideoEntry(
                    id = row.getString("id"), sourceId = row.getString("source"),
                    title = row.getString("title"), uri = row.getString("uri"),
                    positionMs = row.optLong("position"), durationMs = row.optLong("duration"),
                    updatedAt = row.optLong("updated"), nsfw = row.optBoolean("nsfw", false),
                )
            }.getOrNull()
        }.take(60)
    }.getOrDefault(emptyList())

    fun saveHistory(entries: List<VideoEntry>) {
        val array = JSONArray()
        entries.forEach { entry ->
            array.put(JSONObject().apply {
                put("id", entry.id); put("source", entry.sourceId)
                put("title", entry.title); put("uri", entry.uri)
                put("position", entry.positionMs); put("duration", entry.durationMs)
                put("updated", entry.updatedAt); put("nsfw", entry.nsfw)
            })
        }
        prefs.edit().putString("history", array.toString()).apply()
    }
}
