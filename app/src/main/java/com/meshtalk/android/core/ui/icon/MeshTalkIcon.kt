package com.meshtalk.android.core.ui.icon

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/** Compact MeshTalk brand mark used in the chat header and about screen. */
val MeshTalkIcon: ImageVector
    get() {
        _meshTalkIcon?.let { return it }

        return ImageVector.Builder(
            name = "MeshTalkIcon",
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f,
        ).apply {
            // Speech bubble with the MeshTalk-style tail.
            path(fill = SolidColor(Color.Black)) {
                moveTo(3f, 4f)
                lineTo(21f, 4f)
                lineTo(21f, 16f)
                lineTo(14f, 16f)
                lineTo(10f, 20f)
                lineTo(10f, 16f)
                lineTo(3f, 16f)
                close()
            }
            // Heart mark inset into the bubble; the background will visually separate it.
            path(fill = SolidColor(Color.White)) {
                moveTo(12f, 13.6f)
                lineTo(7.8f, 9.7f)
                curveTo(6.2f, 8.2f, 7.2f, 5.8f, 9.3f, 5.8f)
                curveTo(10.4f, 5.8f, 11.3f, 6.4f, 12f, 7.2f)
                curveTo(12.7f, 6.4f, 13.6f, 5.8f, 14.7f, 5.8f)
                curveTo(16.8f, 5.8f, 17.8f, 8.2f, 16.2f, 9.7f)
                close()
            }
        }.build().also { _meshTalkIcon = it }
    }

private var _meshTalkIcon: ImageVector? = null
