package app.meowoo.android

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import app.meowoo.android.model.DeviceMode
import app.meowoo.android.model.deviceMode
import app.meowoo.android.ui.MeowooApp
import app.meowoo.android.ui.MeowooTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mode = deviceMode(BuildConfig.IS_TV, resources.configuration.smallestScreenWidthDp)
        requestedOrientation = when (mode) {
            DeviceMode.PHONE -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            DeviceMode.TABLET -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            DeviceMode.TV -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
        enableEdgeToEdge()
        setContent { MeowooTheme { MeowooApp(viewModel(), mode) } }
    }
}
