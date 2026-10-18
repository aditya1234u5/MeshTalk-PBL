package com.meshtalk.android.ui.theme

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.meshtalk.android.R

/**
 * MeshTalk design system pieces.
 *
 * These are the building blocks of the redesigned app: a soft indigo "aurora" backdrop for
 * full-screen flows, big pill buttons, round avatars and the floating bottom dock that replaces
 * the crowded top-bar buttons of the old layout.
 */

/** Soft vertical aurora: a wash of the brand container colour fading into the background. */
@Composable
fun Modifier.meshTalkBackdrop(): Modifier {
    val scheme = MaterialTheme.colorScheme
    val top = lerp(scheme.background, scheme.primaryContainer, 0.55f)
    val mid = lerp(scheme.background, scheme.primaryContainer, 0.12f)
    return this.background(
        Brush.verticalGradient(
            0f to top,
            0.45f to mid,
            1f to scheme.background,
        )
    )
}

/** Full-width capsule call-to-action. */
@Composable
fun MeshTalkPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(28.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
        ),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

/** Quieter companion to [MeshTalkPrimaryButton]. */
@Composable
fun MeshTalkSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    FilledTonalButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = RoundedCornerShape(26.dp),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

/** Round initial-letter avatar used beside other people's chat bubbles. */
@Composable
fun MeshTalkAvatar(
    name: String,
    color: Color,
    modifier: Modifier = Modifier,
    size: Dp = 32.dp,
) {
    Box(
        modifier = modifier
            .size(size)
            .background(color.copy(alpha = 0.22f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = name.trim().firstOrNull()?.uppercase() ?: "#",
            color = color,
            fontWeight = FontWeight.Bold,
            fontSize = (size.value * 0.42f).sp,
        )
    }
}

/**
 * Floating bottom navigation dock.
 *
 * Replaces the row of tiny buttons that used to be squeezed into the top bar: people nearby,
 * channels, notes and about now live here as labelled, thumb-reachable destinations. It hides
 * itself while the keyboard is open so typing keeps the whole screen.
 */
@Composable
fun MeshTalkDock(
    nearbyCount: Int,
    channelLabel: String,
    isGeoChannel: Boolean,
    onHome: () -> Unit,
    onNearby: () -> Unit,
    onChannels: () -> Unit,
    onNotes: () -> Unit,
    onAbout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val imeBottom = WindowInsets.ime.getBottom(LocalDensity.current)
    if (imeBottom > 0) return

    val scheme = MaterialTheme.colorScheme
    val dockShape = RoundedCornerShape(28.dp)

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 6.dp)
            .shadow(8.dp, dockShape),
        shape = dockShape,
        color = scheme.surface,
        border = BorderStroke(1.dp, scheme.outlineVariant),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            DockItem(
                painter = painterResource(R.drawable.ic_spec_chat_bubbles),
                label = stringResource(R.string.mt_nav_chat),
                selected = true,
                onClick = onHome,
                modifier = Modifier.weight(1f),
            )
            DockItem(
                painter = painterResource(R.drawable.ic_spec_people),
                label = stringResource(R.string.mt_nav_nearby),
                selected = false,
                onClick = onNearby,
                modifier = Modifier.weight(1f),
                badge = nearbyCount,
            )
            DockItem(
                painter = painterResource(
                    if (isGeoChannel) R.drawable.ic_spec_globe else R.drawable.ic_spec_range
                ),
                label = channelLabel,
                selected = false,
                onClick = onChannels,
                modifier = Modifier.weight(1f),
            )
            DockItem(
                painter = painterResource(R.drawable.ic_spec_bookmark_outline),
                label = stringResource(R.string.mt_nav_notes),
                selected = false,
                onClick = onNotes,
                modifier = Modifier.weight(1f),
            )
            DockItem(
                painter = rememberVectorPainter(Icons.Filled.Info),
                label = stringResource(R.string.mt_nav_about),
                selected = false,
                onClick = onAbout,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun DockItem(
    painter: Painter,
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    badge: Int = 0,
) {
    val scheme = MaterialTheme.colorScheme
    val tint = if (selected) scheme.onPrimaryContainer else scheme.onSurfaceVariant

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .height(30.dp)
                .width(52.dp)
                .background(
                    if (selected) scheme.primaryContainer else Color.Transparent,
                    RoundedCornerShape(15.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painter,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(22.dp),
            )
            if (badge > 0) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(end = 2.dp)
                        .defaultMinSize(minWidth = 16.dp, minHeight = 16.dp)
                        .background(scheme.secondary, CircleShape)
                        .padding(horizontal = 4.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = if (badge > 99) "99+" else badge.toString(),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = scheme.onSecondary,
                    )
                }
            }
        }
        Text(
            text = label,
            fontSize = 11.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            color = tint,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
