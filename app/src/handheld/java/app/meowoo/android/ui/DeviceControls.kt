package app.meowoo.android.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun DeviceTheme(content: @Composable () -> Unit) = content()

@Composable
fun ActionButton(label: String, onClick: () -> Unit, modifier: Modifier = Modifier, selected: Boolean = false) {
    Button(onClick = onClick, modifier = modifier,
        border = if (selected) BorderStroke(1.dp, Mint) else null,
        colors = ButtonDefaults.buttonColors(containerColor = if (selected) Mint else Panel, contentColor = if (selected) Canvas else Sky),
    ) { Text(label, maxLines = 1) }
}
