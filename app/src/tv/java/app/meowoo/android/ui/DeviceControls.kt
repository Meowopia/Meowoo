package app.meowoo.android.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp

@Composable
fun DeviceTheme(content: @Composable () -> Unit) {
    content()
}

@Composable
fun ActionButton(label: String, onClick: () -> Unit, modifier: Modifier = Modifier, selected: Boolean = false) {
    var focused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (focused) 1.04f else 1f, label = "TV button focus")
    // A single standard click handler handles touch, accessibility and D-pad activation.
    Button(onClick = onClick, modifier = modifier.heightIn(min = 48.dp)
        .onFocusChanged { focused = it.isFocused }
        .graphicsLayer { scaleX = scale; scaleY = scale },
        border = if (focused) BorderStroke(2.dp, Mint) else null,
        colors = ButtonDefaults.buttonColors(
            containerColor = when { focused -> Sky; selected -> Mint; else -> Panel },
            contentColor = if (focused || selected) Canvas else Sky,
        ),
    ) { Text(label, maxLines = 1) }
}
