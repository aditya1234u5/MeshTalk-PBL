package com.meshtalk.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.meshtalk.android.mesh.LongRangeBle
import com.meshtalk.android.util.BlePhyCapabilities
import com.meshtalk.android.util.DistanceEstimator
import kotlinx.coroutines.delay

/**
 * Small status strip shown above the chat box:
 *  1. whether THIS phone supports Bluetooth 5 long range (Coded PHY), and
 *  2. the estimated distance to each directly connected phone.
 *
 * Distances are estimates from signal strength (see DistanceEstimator), so they are shown with "~".
 */
@Composable
fun LinkStatusStrip(
    viewModel: ChatViewModel,
    colorScheme: ColorScheme,
    modifier: Modifier = Modifier,
    onSearchClick: (() -> Unit)? = null
) {
    val context = LocalContext.current

    // Re-check every few seconds so the label is right if Bluetooth is switched on later
    var report by remember { mutableStateOf(BlePhyCapabilities.check(context)) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(3000)
            report = BlePhyCapabilities.check(context)
        }
    }

    val connectedPeers by viewModel.connectedPeers.collectAsStateWithLifecycle()
    val nicknames by viewModel.peerNicknames.collectAsStateWithLifecycle()
    val rssiMap by viewModel.peerRSSI.collectAsStateWithLifecycle()

    val muted = colorScheme.onSurfaceVariant
    val (dotColor, rangeText) = when {
        !LongRangeBle.ENABLED -> muted to "Long range: off in this build"
        !report.bluetoothOn -> muted to "Long range: checking (turn Bluetooth on)"
        report.canUseLongRange -> Color(0xFF3FB950) to "Long range: supported"
        else -> Color(0xFFF0883E) to "Long range: not supported on this phone"
    }

    // Peers with a usable signal reading are directly connected phones; the rest are reached via relays
    val direct = connectedPeers.mapNotNull { id ->
        val rssi = rssiMap[id]?.takeIf { it in -127..-1 } ?: return@mapNotNull null
        (nicknames[id] ?: id.take(8)) to rssi
    }
    val relayed = connectedPeers.size - direct.size
    val peersText = when {
        connectedPeers.isEmpty() -> "No phones connected"
        direct.isEmpty() -> "${connectedPeers.size} connected via relay (distance unknown)"
        else -> direct.joinToString("  |  ") { (name, rssi) ->
            "$name ~${DistanceEstimator.format(rssi)}"
        } + if (relayed > 0) "  |  +$relayed via relay" else ""
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(dotColor)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = rangeText,
                fontSize = 11.sp,
                color = muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            if (onSearchClick != null) {
                IconButton(onClick = onSearchClick, modifier = Modifier.size(28.dp)) {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search messages",
                        tint = muted,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
        Text(
            text = peersText,
            fontSize = 11.sp,
            color = muted,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}
