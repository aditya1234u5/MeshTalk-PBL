package com.meshtalk.android.util

import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Rough distance estimate from Bluetooth signal strength (RSSI).
 *
 * Bluetooth cannot measure distance directly. This uses the common log-distance model:
 *   distance = 10 ^ ((RSSI at 1 m - RSSI) / (10 * n))
 * Real signals vary a lot with phone model, walls, bodies and reflections, so the result is only
 * a ballpark figure and is always shown with "~".
 */
object DistanceEstimator {

    /** Typical signal strength (dBm) measured 1 m from another phone. Varies by phone model. */
    const val RSSI_AT_1M_DBM = -59

    /** Path-loss exponent: about 2 in open air, 3 to 4 indoors. 2.5 is a middle value. */
    const val PATH_LOSS_EXPONENT = 2.5

    fun estimateMeters(rssi: Int): Double =
        10.0.pow((RSSI_AT_1M_DBM - rssi) / (10.0 * PATH_LOSS_EXPONENT))

    /** Human-readable rounded distance, e.g. "<1 m", "7 m", "35 m", "120 m". */
    fun format(rssi: Int): String {
        val m = estimateMeters(rssi)
        return when {
            m < 1.0 -> "<1 m"
            m < 10.0 -> "${m.roundToInt()} m"
            m < 100.0 -> "${(m / 5.0).roundToInt() * 5} m"
            m < 1000.0 -> "${(m / 10.0).roundToInt() * 10} m"
            else -> ">1 km"
        }
    }
}
