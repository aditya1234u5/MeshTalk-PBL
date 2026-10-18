package com.meshtalk.android.ui

import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/*
 * MeshTalk additions on top of the shared bitchat protocol.
 *
 * Everything in this file travels as ordinary public text messages. No packet, fragment or
 * encryption format is touched, so MeshTalk stays wire-compatible with bitchat: other clients just
 * show the text with its prefix. The helpers are plain Kotlin (no Android types) so they can be
 * unit tested on the JVM.
 */

/** Text conventions for the emergency SOS broadcast. */
object SosProtocol {
    /** Start of every SOS broadcast: the SOS emoji followed by "SOS". */
    const val SOS_PREFIX = "🆘 SOS"

    /** Start of the reply that tells a sender somebody has seen their SOS. */
    const val ACK_PREFIX = "✅ SOS acknowledged"

    const val MAX_DETAIL_LENGTH = 140

    /**
     * Build the SOS text. [geohash] is optional and is only a coarse area code (the caller decides
     * whether the user has location enabled); it is never a precise coordinate.
     */
    fun build(detail: String?, geohash: String?): String {
        val builder = StringBuilder(SOS_PREFIX)
        val cleanDetail = detail?.trim().orEmpty().take(MAX_DETAIL_LENGTH)
        if (cleanDetail.isNotEmpty()) {
            builder.append(": ").append(cleanDetail)
        }
        val cleanGeohash = geohash?.trim().orEmpty()
        if (cleanGeohash.isNotEmpty()) {
            builder.append(" (near geohash ").append(cleanGeohash).append(')')
        }
        return builder.toString()
    }

    fun buildAck(nickname: String?): String {
        val who = nickname?.trim().orEmpty().ifEmpty { "someone" }
        return "$ACK_PREFIX by $who"
    }

    fun isSos(content: String): Boolean = content.startsWith(SOS_PREFIX)

    fun isAck(content: String): Boolean = content.startsWith(ACK_PREFIX)
}

/**
 * Sends an SOS message several times so that peers who were out of range (or had Bluetooth busy)
 * for the first transmission still get it, and stops as soon as somebody acknowledges it.
 */
class SosBroadcaster(
    private val scope: CoroutineScope,
    private val send: (String) -> Unit,
    private val repeatCount: Int = DEFAULT_REPEATS,
    private val intervalMs: Long = DEFAULT_INTERVAL_MS
) {
    @Volatile
    private var job: Job? = null

    val isActive: Boolean
        get() = job?.isActive == true

    /** Starts repeating [message]. Returns false (and does nothing) if a broadcast is running. */
    fun start(message: String): Boolean {
        if (isActive) return false
        job = scope.launch {
            for (attempt in 0 until repeatCount) {
                if (attempt > 0) delay(intervalMs)
                send(message)
            }
        }
        return true
    }

    /** Stops repeating. Returns true if a broadcast was actually running. */
    fun cancel(): Boolean {
        val wasActive = isActive
        job?.cancel()
        job = null
        return wasActive
    }

    /** Called when an acknowledgement arrives. Returns true if it stopped a running broadcast. */
    fun onAckReceived(): Boolean = cancel()

    companion object {
        const val DEFAULT_REPEATS = 5
        const val DEFAULT_INTERVAL_MS = 30_000L
    }
}

/** Text conventions for mesh announcements. */
object NoticeProtocol {
    const val PREFIX = "📢 NOTICE"
    const val MAX_TEXT_LENGTH = 280
    const val EXPIRY_MS = 24L * 60L * 60L * 1000L

    fun build(text: String): String = "$PREFIX: ${text.trim().take(MAX_TEXT_LENGTH)}"

    /** Returns the announcement text, or null if [content] is not a notice. */
    fun parse(content: String): String? {
        val marker = "$PREFIX:"
        if (!content.startsWith(marker)) return null
        return content.removePrefix(marker).trim().ifEmpty { null }
    }
}

/**
 * Remembers the announcements this device has seen and forgets them after
 * [NoticeProtocol.EXPIRY_MS]. Kept in memory only, so the list is empty after the app restarts.
 */
class NoticeBoard(private val clock: () -> Long = { System.currentTimeMillis() }) {
    data class Notice(val id: String, val sender: String, val text: String, val postedAtMs: Long)

    private val notices = ConcurrentHashMap<String, Notice>()

    /** Records [content] if it is a fresh notice not seen before. Returns true if it was added. */
    fun record(id: String, sender: String, content: String, postedAtMs: Long): Boolean {
        val text = NoticeProtocol.parse(content) ?: return false
        if (isExpired(postedAtMs)) return false
        return notices.putIfAbsent(id, Notice(id, sender, text, postedAtMs)) == null
    }

    /** Notices that have not expired yet, newest first. */
    fun active(): List<Notice> {
        notices.values.removeIf { isExpired(it.postedAtMs) }
        return notices.values.sortedByDescending { it.postedAtMs }
    }

    private fun isExpired(postedAtMs: Long): Boolean = clock() - postedAtMs > NoticeProtocol.EXPIRY_MS
}

/** Turns a Bluetooth signal strength reading into a word people understand. */
object SignalQuality {
    fun label(rssiDbm: Int): String = when {
        rssiDbm >= -60 -> "excellent"
        rssiDbm >= -70 -> "good"
        rssiDbm >= -80 -> "fair"
        else -> "weak"
    }
}

/** Channels every new MeshTalk install joins automatically so campus users find each other. */
object CampusChannels {
    val DEFAULTS: List<String> = listOf("#hostel", "#library", "#exams")
    const val PREFS_NAME = "meshtalk_extras"
    const val KEY_SEEDED = "campus_channels_seeded"
}

/**
 * Text shown after a message's timestamp, e.g. " · 2 hops". Empty for messages that arrived
 * directly (zero hops) or whose hop count is unknown.
 */
fun hopsSuffix(hops: Int?): String = when {
    hops == null || hops <= 0 -> ""
    hops == 1 -> " · 1 hop"
    else -> " · $hops hops"
}
