package app.meowoo.android.model

import org.junit.Assert.*
import org.junit.Test

class LibraryTest {
    private fun entry(id: String, source: String = "local", nsfw: Boolean = false) = VideoEntry(id, source, "Fixture", "https://example.test/video.mp4", nsfw = nsfw)

    @Test fun phoneTabletAndTvHaveDistinctLayouts() {
        assertEquals(DeviceMode.PHONE, deviceMode(false, 599))
        assertEquals(DeviceMode.TABLET, deviceMode(false, 600))
        assertEquals(DeviceMode.TV, deviceMode(true, 320))
    }

    @Test fun nsfwFiltersSourcesAndMixedSourceEntries() {
        assertFalse(Sources.visible(false).any { it.id == "huangguo" })
        assertTrue(Sources.visible(true).any { it.id == "huangguo" })
        assertTrue(entry("1").visible(false))
        assertFalse(entry("1", "huangguo").visible(false))
        assertFalse(entry("1", nsfw = true).visible(false))
        assertFalse(entry("1", "unknown").visible(true))
        assertTrue(entry("1", "huangguo").visible(true))
    }

    @Test fun playbackAddressAllowsHttpsButNotCredentialsOrOtherSchemes() {
        assertEquals("https://example.test/v.m3u8?q=1", validatedPlaybackUrl("  https://example.test/v.m3u8?q=1  "))
        listOf("http://example.test/v", "file:///private", "javascript:alert(1)", "https://", "https://u:p@example.test/v").forEach {
            assertNull(it, validatedPlaybackUrl(it))
        }
    }

    @Test fun historyNeverCollidesBetweenSources() {
        val first = entry("42").copy(positionMs = 20_000)
        val second = entry("42", "huangguo")
        val history = upsertHistory(listOf(first), second)
        assertEquals(2, history.size)
        val updated = upsertHistory(history, first.copy(positionMs = 30_000))
        assertEquals(2, updated.size)
        assertEquals(30_000, updated.first().positionMs)
        assertEquals("huangguo:42", updated.last().key)
    }

    @Test fun historyIsBoundedAndNormalizesInvalidPlayerTimes() {
        var history = emptyList<VideoEntry>()
        repeat(65) { history = upsertHistory(history, entry(it.toString())) }
        assertEquals(60, history.size)
        assertEquals("64", history.first().id)
        val normalized = upsertHistory(history, entry("new").copy(positionMs = -1, durationMs = Long.MIN_VALUE)).first()
        assertEquals(0, normalized.positionMs)
        assertEquals(0, normalized.durationMs)
    }

    @Test fun completedVideosRestartButUnfinishedVideosResume() {
        assertEquals(0, playbackStartPosition(59_000, 60_000))
        assertEquals(30_000, playbackStartPosition(30_000, 60_000))
        assertEquals(30_000, playbackStartPosition(30_000, 0))
    }
}
