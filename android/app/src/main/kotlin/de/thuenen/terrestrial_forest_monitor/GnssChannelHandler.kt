package de.thuenen.terrestrial_forest_monitor

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.LocationManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class GnssChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        const val METHOD_CHANNEL = "com.thuenen.tfm/gnss"
        const val EVENT_CHANNEL = "com.thuenen.tfm/gnss_status"
    }

    private var locationManager: LocationManager? = null
    private var gnssStatusCallback: GnssStatus.Callback? = null
    private var eventSink: EventChannel.EventSink? = null

    init {
        locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startGnssListener" -> {
                startGnssListener(result)
            }
            "stopGnssListener" -> {
                stopGnssListener(result)
            }
            "isGnssAvailable" -> {
                result.success(isGnssAvailable())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isGnssAvailable(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            locationManager != null
        } else {
            false
        }
    }

    private fun startGnssListener(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            result.error("API_LEVEL", "GNSS Status requires Android 7.0 (API 24) or higher", null)
            return
        }

        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION", "Location permission not granted", null)
            return
        }

        try {
            if (gnssStatusCallback == null) {
                gnssStatusCallback = object : GnssStatus.Callback() {
                    override fun onSatelliteStatusChanged(status: GnssStatus) {
                        sendGnssStatus(status)
                    }

                    override fun onStarted() {
                        // GNSS started
                    }

                    override fun onStopped() {
                        // GNSS stopped
                    }
                }
            }

            locationManager?.registerGnssStatusCallback(gnssStatusCallback!!, null)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to start GNSS listener: ${e.message}", null)
        }
    }

    private fun stopGnssListener(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            result.success(false)
            return
        }

        try {
            gnssStatusCallback?.let {
                locationManager?.unregisterGnssStatusCallback(it)
                gnssStatusCallback = null
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to stop GNSS listener: ${e.message}", null)
        }
    }

    private fun sendGnssStatus(status: GnssStatus) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        val satelliteCount = status.satelliteCount
        var usedInFix = 0
        val satellites = mutableListOf<Map<String, Any>>()

        for (i in 0 until satelliteCount) {
            val usedInFixSat = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                status.usedInFix(i)
            } else {
                // Fallback: assume satellites with good signal are used in fix
                status.getCn0DbHz(i) > 20.0
            }

            if (usedInFixSat) {
                usedInFix++
            }

            val satelliteInfo = mapOf(
                "svid" to status.getSvid(i),
                "constellationType" to status.getConstellationType(i),
                "cn0DbHz" to status.getCn0DbHz(i),
                "elevation" to status.getElevationDegrees(i),
                "azimuth" to status.getAzimuthDegrees(i),
                "usedInFix" to usedInFixSat
            )
            satellites.add(satelliteInfo)
        }

        val gnssStatusMap = mapOf(
            "satelliteCount" to satelliteCount,
            "usedInFix" to usedInFix,
            "satellites" to satellites
        )

        eventSink?.success(gnssStatusMap)
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun cleanup() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            gnssStatusCallback?.let {
                locationManager?.unregisterGnssStatusCallback(it)
            }
        }
        gnssStatusCallback = null
        eventSink = null
    }
}
