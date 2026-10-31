package com.meshtalk.android.mesh

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult

/**
 * Bluetooth 5 Coded PHY ("long range") settings and helpers.
 *
 * Coded PHY sends every bit with extra error-correction, so a receiver can understand much
 * weaker signals. The cost is a lower data rate (125 kbps with S8) and the fact that BOTH phones
 * must support it. Phones that don't support it keep using normal Bluetooth LE.
 */
object LongRangeBle {

    /** Master switch. Set to false to build a "before" version for range comparison tests. */
    const val ENABLED = true

    /**
     * Coded PHY coding scheme for links that use it.
     * PHY_OPTION_S8 = 125 kbps (longest range). PHY_OPTION_S2 = 500 kbps (faster, less extra range).
     */
    val CODED_PHY_OPTION: Int = BluetoothDevice.PHY_OPTION_S8

    /** Weakest Coded PHY advert (dBm) we will still try to connect to. */
    const val CODED_MIN_RSSI_DBM = -105

    /**
     * Coded PHY adverts stronger than this (dBm) are ignored, because the phone is close enough
     * for a normal fast link. Weaker ones may be connected over the Coded PHY.
     */
    const val CODED_SKIP_ABOVE_DBM = -70

    /** True when long range is switched on AND this phone supports Coded PHY + extended advertising. */
    fun isSupported(adapter: BluetoothAdapter?): Boolean {
        if (!ENABLED || adapter == null) return false
        return try {
            adapter.isLeCodedPhySupported && adapter.isLeExtendedAdvertisingSupported
        } catch (e: Exception) {
            false
        }
    }

    /** True when this scan result arrived on the Coded PHY (a long-range advert). */
    fun isCodedResult(result: ScanResult): Boolean {
        return try {
            result.primaryPhy == BluetoothDevice.PHY_LE_CODED
        } catch (e: Exception) {
            false
        }
    }

    fun phyName(phy: Int): String = when (phy) {
        BluetoothDevice.PHY_LE_1M -> "1M"
        BluetoothDevice.PHY_LE_2M -> "2M"
        BluetoothDevice.PHY_LE_CODED -> "CODED"
        else -> "unknown($phy)"
    }
}
