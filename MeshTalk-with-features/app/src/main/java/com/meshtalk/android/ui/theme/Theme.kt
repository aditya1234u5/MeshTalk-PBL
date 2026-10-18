package com.meshtalk.android.ui.theme

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.WindowInsetsController
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp

// MeshTalk identity: midnight ink surfaces with an indigo primary and a cyan secondary.
// Standard UI semantics live in Material so stock components and custom composables share one
// source of truth. LocalBitchatPalette below only supplies app-specific extra colors.
internal val DarkBitchatColorScheme = darkColorScheme(
    primary = Color(0xFF7C8CFF),
    onPrimary = Color(0xFF0B0D14),
    primaryContainer = Color(0xFF2A3496),
    onPrimaryContainer = Color(0xFFDDE1FF),
    secondary = Color(0xFF22D3EE),
    onSecondary = Color.Black,
    secondaryContainer = Color(0xFF0C3A45),
    onSecondaryContainer = Color(0xFFC5F3FB),
    tertiary = DarkBitchatPalette.accentOrange,
    onTertiary = Color.Black,
    background = Color(0xFF0B0D14),
    onBackground = Color(0xFFF2F4FA),
    surface = Color(0xFF121624),
    onSurface = Color(0xFFF2F4FA),
    surfaceVariant = Color(0xFF1B2133),
    onSurfaceVariant = Color(0xFFA3ACC7),
    outline = Color(0xFF2E3550),
    outlineVariant = Color(0xFF1F2538),
    error = Color(0xFFFF5C6C),
    errorContainer = Color(0xFF4A1620),
    onError = Color.Black
)

internal val LightBitchatColorScheme = lightColorScheme(
    primary = Color(0xFF4756D6),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFDDE2FF),
    onPrimaryContainer = Color(0xFF0E1654),
    secondary = Color(0xFF0E7490),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFCFF4FA),
    onSecondaryContainer = Color(0xFF053340),
    tertiary = LightBitchatPalette.accentOrange,
    onTertiary = Color.Black,
    background = Color(0xFFF7F8FC),
    onBackground = Color(0xFF121524),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF121524),
    surfaceVariant = Color(0xFFEBEDF7),
    onSurfaceVariant = Color(0xFF4E5675),
    outline = Color(0xFFD0D5E6),
    outlineVariant = Color(0xFFE1E5F1),
    error = Color(0xFFD3243A),
    errorContainer = Color(0xFFFFDADF),
    onError = Color.White
)

// Soft, generously rounded corners everywhere (sheets, dialogs, buttons, cards).
private val MeshTalkShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp),
)

@Composable
fun BitchatTheme(
    darkTheme: Boolean? = null,
    content: @Composable () -> Unit
) {
    // App-level override from ThemePreferenceManager
    val themePref by ThemePreferenceManager.themeFlow.collectAsState(initial = ThemePreference.System)
    val shouldUseDark = when (darkTheme) {
        true -> true
        false -> false
        null -> when (themePref) {
            ThemePreference.Dark -> true
            ThemePreference.Light -> false
            ThemePreference.System -> isSystemInDarkTheme()
        }
    }

    val colorScheme = if (shouldUseDark) DarkBitchatColorScheme else LightBitchatColorScheme
    val palette = if (shouldUseDark) DarkBitchatPalette else LightBitchatPalette

    val view = LocalView.current
    SideEffect {
        (view.context as? Activity)?.window?.let { window ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.setSystemBarsAppearance(
                    if (!shouldUseDark) WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS else 0,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                )
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = if (!shouldUseDark) {
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                } else 0
            }
            window.navigationBarColor = colorScheme.background.toArgb()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
        }
    }

    CompositionLocalProvider(LocalBitchatPalette provides palette) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            shapes = MeshTalkShapes,
            content = content
        )
    }
}
