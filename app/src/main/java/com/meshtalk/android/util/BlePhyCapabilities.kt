package com.meshtalk.android.util

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Build

/**
 * Temporary helper: reports whether THIS phone supports the BLE 5 features
 * needed for Coded PHY (long range).
 *
 * Put this file in: app/src/main/java/com/meshtalk/android/util/
 * Run it on EVERY phone you plan to test with, with Bluetooth turned ON.
 * (With Bluetooth off, Android may report "false" even if the hardware supports it.)
 */
object BlePhyCapabilities {

    data class Report(
        val device: String,
        val androidApi: Int,
        val bluetoothOn: Boolean,
        val codedPhy: Boolean,
        val extendedAdvertising: Boolean,
        val twoMPhy: Boolean,
        val maxAdvDataBytes: Int
    ) {
        /** Long range needs BOTH: Coded PHY and extended advertising. */
        val canUseLongRange: Boolean get() = codedPhy && extendedAdvertising

        fun summary(): String = buildString {
            appendLine("Device: $device")
            appendLine("Android API: $androidApi")
            appendLine("Bluetooth on: ${yesNo(bluetoothOn)}")
            appendLine("Coded PHY: ${yesNo(codedPhy)}")
            appendLine("Extended advertising: ${yesNo(extendedAdvertising)}")
            appendLine("2M PHY: ${yesNo(twoMPhy)}")
            appendLine("Max advert data: $maxAdvDataBytes bytes")
            append("LONG RANGE USABLE: ${yesNo(canUseLongRange)}")
            if (!bluetoothOn) {
                append("\n(Turn Bluetooth ON and run again - results may be wrong)")
            }
        }

        private fun yesNo(value: Boolean) = if (value) "YES" else "NO"
    }

    fun check(context: Context): Report {
        val adapter: BluetoothAdapter? =
            (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

        return Report(
            device = "${Build.MANUFACTURER} ${Build.MODEL}",
            androidApi = Build.VERSION.SDK_INT,
            bluetoothOn = safe(false) { adapter?.isEnabled == true },
            codedPhy = safe(false) { adapter?.isLeCodedPhySupported == true },
            extendedAdvertising = safe(false) { adapter?.isLeExtendedAdvertisingSupported == true },
            twoMPhy = safe(false) { adapter?.isLe2MPhySupported == true },
            maxAdvDataBytes = safe(0) { adapter?.leMaximumAdvertisingDataLength ?: 0 }
        )
    }

    // Capability queries should not crash the app if a phone behaves oddly.
    private inline fun <T> safe(default: T, block: () -> T): T =
        try {
            block()
        } catch (e: Exception) {
            default
        }
}
