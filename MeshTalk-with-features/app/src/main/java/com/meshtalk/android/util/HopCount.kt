package com.meshtalk.android.util

/**
 * How many relays a packet passed through before reaching this device.
 *
 * Each relay lowers the packet's TTL by one, so the hops are the starting TTL minus what is left.
 * Never negative: a sender that used a larger starting TTL than ours simply reads as zero.
 */
fun hopsTraveled(
    remainingTtl: UByte,
    startingTtl: UByte = AppConstants.MESSAGE_TTL_HOPS
): Int = (startingTtl.toInt() - remainingTtl.toInt()).coerceAtLeast(0)
