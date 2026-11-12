package app.meowoo.android

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.InputMode
import androidx.compose.ui.input.InputModeManager
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.LocalInputModeManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.meowoo.android.ui.ActionButton
import app.meowoo.android.ui.MeowooTheme
import app.meowoo.android.ui.TvTouchPlaybackHeader
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DualInputTest {
    @get:Rule val compose = createComposeRule()

    @OptIn(ExperimentalTestApi::class)
    @Test fun touchAndDpadEachActivateExactlyOnce() {
        var clicks = 0
        lateinit var inputMode: InputModeManager
        val focus = FocusRequester()
        compose.setContent {
            inputMode = LocalInputModeManager.current
            MeowooTheme {
                ActionButton("操作", { clicks++ }, Modifier.testTag("action").focusRequester(focus))
            }
        }
        compose.onNodeWithTag("action").performTouchInput { click() }
        compose.runOnIdle { assertEquals(1, clicks); inputMode.requestInputMode(InputMode.Keyboard); focus.requestFocus() }
        compose.onNodeWithTag("action").assertIsFocused().performKeyInput { pressKey(Key.DirectionCenter) }
        compose.runOnIdle { assertEquals(2, clicks) }
        compose.onNodeWithTag("action").performTouchInput { click() }
        compose.runOnIdle { assertEquals(3, clicks) }
    }

    @Test fun playerHasATouchExitWithoutHardwareBack() {
        var closed = false
        compose.setContent { MeowooTheme { TvTouchPlaybackHeader("测试视频", { closed = true }) } }
        compose.onNodeWithText("返回片库").performTouchInput { click() }
        compose.runOnIdle { assertEquals(true, closed) }
    }
}
