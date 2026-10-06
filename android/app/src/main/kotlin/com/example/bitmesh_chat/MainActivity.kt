package com.example.bitmesh_chat

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * Replaces flutter_ble_peripheral for the peripheral/GATT-server role only
 * (central/scanning stays on flutter_blue_plus, unaffected).
 *
 * WHY THIS EXISTS: Android's own BluetoothGattServerCallback.onCharacteristicWriteRequest
 * gives you the writing BluetoothDevice directly - its address is the real
 * identity of whoever just wrote. flutter_ble_peripheral's Dart-facing
 * onDataReceived stream never surfaces that device, only raw bytes, which
 * made it impossible to tell apart multiple simultaneously-connected
 * centrals writing to the same phone (confirmed as the root cause of
 * cross-attributed messages during 2-phone testing). This file captures
 * that identity natively and forwards (address, bytes) to Dart untouched.
 */
class MainActivity : FlutterActivity() {
    private val tag = "MeshGattServer"
    private val serviceUuid = "7a4f2c10-9b3d-4e8a-8c1a-1a2b3c4d5e6f"
    private val charUuid = "7a4f2c11-9b3d-4e8a-8c1a-1a2b3c4d5e6f"

    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "bitmesh/gatt_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bitmesh/gatt_methods")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startGattServer()
                        result.success(null)
                    }
                    "stop" -> {
                        stopGattServer()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startGattServer() {
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter

        gattServer = btManager.openGattServer(this, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                Log.i(tag, "onConnectionStateChange: ${device.address} status=$status newState=$newState")
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray
            ) {
                Log.i(tag, "write from ${device.address}, ${value.size} bytes")
                // GATT callbacks fire on a binder thread, but EventChannel's
                // success() must run on the main thread - confirmed via a
                // real crash here on first use (RuntimeException: Methods
                // marked with @UiThread must be executed on the main thread).
                runOnUiThread {
                    eventSink?.success(mapOf("address" to device.address, "bytes" to value.toList()))
                }
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
            }
        })

        val service = BluetoothGattService(
            UUID.fromString(serviceUuid),
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )
        val characteristic = BluetoothGattCharacteristic(
            UUID.fromString(charUuid),
            BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(characteristic)
        gattServer?.addService(service)

        advertiser = adapter.bluetoothLeAdvertiser
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()
        // Deliberately no device name in the advertisement - matches the
        // earlier fix in the Dart layer (identity no longer needs to ride
        // in the advertised name at all now that this bridge exists), and
        // keeps the packet safely under BLE's 31-byte legacy limit.
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid.fromString(serviceUuid))
            .build()

        advertiser?.startAdvertising(settings, data, object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                Log.i(tag, "advertising started")
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e(tag, "advertising FAILED, code=$errorCode")
            }
        })
    }

    private fun stopGattServer() {
        advertiser?.stopAdvertising(object : AdvertiseCallback() {})
        gattServer?.close()
        gattServer = null
    }
}
