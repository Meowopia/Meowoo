package app.meowoo.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NavigationTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun settingsAreAvailableWithoutAccountAndSourceVisibilityChangesImmediately() {
        compose.onNodeWithText("设置").performTouchInput { click() }
        val off = compose.onAllNodesWithText("已关闭 · 点击开启")
        if (off.fetchSemanticsNodes().isEmpty()) compose.onNodeWithText("已开启 · 点击关闭").performClick()
        compose.onNodeWithText("内容源").performTouchInput { click() }
        compose.onNodeWithText("黄果 · 18+").assertDoesNotExist()
        compose.onNodeWithText("红果短剧").assertExists()
        compose.onNodeWithText("设置").performClick()
        compose.onNodeWithText("已关闭 · 点击开启").performTouchInput { click() }
        compose.onNodeWithText("内容源").performClick()
        compose.onNodeWithText("黄果 · 18+").assertExists()
        compose.onNodeWithText("设置").performClick()
        compose.onNodeWithText("已开启 · 点击关闭").performClick()
    }
}
