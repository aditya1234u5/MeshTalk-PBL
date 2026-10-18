package com.meshtalk.android.ui

import com.meshtalk.android.util.hopsTraveled
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for the MeshTalk additions. All data is synthetic; the geohash below is a well-known
 * documentation example and is not a real location.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class MeshTalkExtrasTest {

    // region SOS text

    @Test
    fun `sos with details and area code includes both`() {
        val text = SosProtocol.build("stuck in the lab", "ezs42e")

        assertEquals("${SosProtocol.SOS_PREFIX}: stuck in the lab (near geohash ezs42e)", text)
        assertTrue(SosProtocol.isSos(text))
    }

    @Test
    fun `sos without details or area code is just the prefix`() {
        assertEquals(SosProtocol.SOS_PREFIX, SosProtocol.build(null, null))
        assertEquals(SosProtocol.SOS_PREFIX, SosProtocol.build("   ", "  "))
    }

    @Test
    fun `sos details are trimmed to the maximum length`() {
        val text = SosProtocol.build("x".repeat(500), null)

        val detail = text.removePrefix("${SosProtocol.SOS_PREFIX}: ")
        assertEquals(SosProtocol.MAX_DETAIL_LENGTH, detail.length)
    }

    @Test
    fun `acknowledgement names the sender or falls back to someone`() {
        assertEquals("${SosProtocol.ACK_PREFIX} by Asha", SosProtocol.buildAck("Asha"))
        assertEquals("${SosProtocol.ACK_PREFIX} by someone", SosProtocol.buildAck("  "))
        assertTrue(SosProtocol.isAck(SosProtocol.buildAck(null)))
        assertFalse(SosProtocol.isSos(SosProtocol.buildAck(null)))
    }

    // endregion

    // region SOS repeating

    @Test
    fun `sos is repeated at the interval and then finishes`() {
        val scope = TestScope()
        val sent = mutableListOf<String>()
        val broadcaster = SosBroadcaster(scope, { sent.add(it) }, repeatCount = 3, intervalMs = 1_000L)

        assertTrue(broadcaster.start("alert"))
        scope.testScheduler.runCurrent()
        assertEquals(1, sent.size)

        scope.testScheduler.advanceTimeBy(1_000L)
        scope.testScheduler.runCurrent()
        assertEquals(2, sent.size)

        scope.testScheduler.advanceTimeBy(1_000L)
        scope.testScheduler.runCurrent()
        assertEquals(3, sent.size)

        scope.testScheduler.advanceUntilIdle()
        assertEquals(3, sent.size)
        assertFalse(broadcaster.isActive)
    }

    @Test
    fun `acknowledgement stops the repeating`() {
        val scope = TestScope()
        val sent = mutableListOf<String>()
        val broadcaster = SosBroadcaster(scope, { sent.add(it) }, repeatCount = 5, intervalMs = 1_000L)
        broadcaster.start("alert")
        scope.testScheduler.runCurrent()
        assertEquals(1, sent.size)

        assertTrue(broadcaster.onAckReceived())
        scope.testScheduler.advanceUntilIdle()

        assertEquals(1, sent.size)
        assertFalse(broadcaster.isActive)
        assertFalse(broadcaster.onAckReceived())
    }

    @Test
    fun `starting twice while running is refused`() {
        val scope = TestScope()
        val broadcaster = SosBroadcaster(scope, { }, repeatCount = 5, intervalMs = 1_000L)

        assertTrue(broadcaster.start("first"))
        assertFalse(broadcaster.start("second"))
        assertTrue(broadcaster.cancel())
        assertFalse(broadcaster.cancel())
    }

    // endregion

    // region Announcements

    @Test
    fun `notice text round trips`() {
        val text = NoticeProtocol.build("  exam hall moved to block C  ")

        assertEquals("${NoticeProtocol.PREFIX}: exam hall moved to block C", text)
        assertEquals("exam hall moved to block C", NoticeProtocol.parse(text))
    }

    @Test
    fun `plain messages and empty notices are not notices`() {
        assertNull(NoticeProtocol.parse("hello everyone"))
        assertNull(NoticeProtocol.parse("${NoticeProtocol.PREFIX}:   "))
    }

    @Test
    fun `notice board ignores duplicates and non notices`() {
        val board = NoticeBoard(clock = { 10_000L })

        assertTrue(board.record("1", "Asha", NoticeProtocol.build("lab closed"), 9_000L))
        assertFalse(board.record("1", "Asha", NoticeProtocol.build("lab closed"), 9_000L))
        assertFalse(board.record("2", "Ravi", "just chatting", 9_500L))

        assertEquals(listOf("lab closed"), board.active().map { it.text })
    }

    @Test
    fun `notice board lists newest first and forgets expired notices`() {
        var now = 1_000_000L
        val board = NoticeBoard(clock = { now })
        board.record("old", "Asha", NoticeProtocol.build("first"), now)
        now += 60_000L
        board.record("new", "Ravi", NoticeProtocol.build("second"), now)

        assertEquals(listOf("second", "first"), board.active().map { it.text })

        now += NoticeProtocol.EXPIRY_MS - 30_000L
        assertEquals(listOf("second"), board.active().map { it.text })

        now += 60_000L
        assertTrue(board.active().isEmpty())
    }

    @Test
    fun `notice board refuses a notice that is already expired`() {
        val now = 10L * NoticeProtocol.EXPIRY_MS
        val board = NoticeBoard(clock = { now })

        assertFalse(board.record("stale", "Asha", NoticeProtocol.build("old news"), 0L))
        assertTrue(board.active().isEmpty())
    }

    // endregion

    // region Signal, hops and channels

    @Test
    fun `signal labels follow the rssi thresholds`() {
        assertEquals("excellent", SignalQuality.label(-45))
        assertEquals("excellent", SignalQuality.label(-60))
        assertEquals("good", SignalQuality.label(-65))
        assertEquals("fair", SignalQuality.label(-75))
        assertEquals("weak", SignalQuality.label(-81))
        assertEquals("weak", SignalQuality.label(-100))
    }

    @Test
    fun `hop suffix is empty for direct or unknown and pluralises otherwise`() {
        assertEquals("", hopsSuffix(null))
        assertEquals("", hopsSuffix(0))
        assertEquals(" · 1 hop", hopsSuffix(1))
        assertEquals(" · 3 hops", hopsSuffix(3))
    }

    @Test
    fun `hops are the starting ttl minus the remaining ttl and never negative`() {
        assertEquals(0, hopsTraveled(7u))
        assertEquals(2, hopsTraveled(5u))
        assertEquals(7, hopsTraveled(0u))
        assertEquals(0, hopsTraveled(9u))
        assertEquals(3, hopsTraveled(remainingTtl = 4u, startingTtl = 7u))
    }

    @Test
    fun `campus channels are distinct lowercase hashtags`() {
        val channels = CampusChannels.DEFAULTS

        assertTrue(channels.isNotEmpty())
        assertEquals(channels.size, channels.toSet().size)
        assertTrue(channels.all { it.startsWith("#") && it == it.lowercase() && !it.contains(' ') })
    }

    // endregion
}
