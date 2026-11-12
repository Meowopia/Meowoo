package app.meowoo.android.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Mint = Color(0xFF7BE3CC)
val Sky = Color(0xFF92CFFF)
val Canvas = Color(0xFF0A1422)
val Panel = Color(0xFF142337)
val Muted = Color(0xFFA6B7CA)

@Composable
fun MeowooTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = darkColorScheme(
        primary = Mint, onPrimary = Canvas,
        secondary = Sky, onSecondary = Canvas,
        background = Canvas, onBackground = Color(0xFFF0F6FC),
        surface = Panel, onSurface = Color(0xFFF0F6FC),
        surfaceVariant = Color(0xFF1C3045), onSurfaceVariant = Muted,
    )) { DeviceTheme(content) }
}
