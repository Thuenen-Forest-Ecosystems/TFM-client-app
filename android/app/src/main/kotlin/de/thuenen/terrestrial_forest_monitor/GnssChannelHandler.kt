package de.thuenen.terrestrial_forest_monitor

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class GnssChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        const val METHOD_CHANNEL = "com.thuenen.tfm/gnss"
        const val EVENT_CHANNEL = "com.thuenen.tfm/gnss_status"
        const val LOCATION_EXTRAS_EVENT_CHANNEL = "com.thuenen.tfm/location_extras"
    }

    private var locationManager: LocationManager? = null
    private var gnssStatusCallback: GnssStatus.Callback? = null
    private var gnssEventSink: EventChannel.EventSink? = null
    private var locationExtrasEventSink: EventChannel.EventSink? = null
    private var locationListener: LocationListener? = null

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
            "startLocationExtrasListener" -> {
                startLocationExtrasListener(result)
            }
            "stopLocationExtrasListener" -> {
                stopLocationExtrasListener(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED || ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
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

        if (!hasLocationPermission()) {
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

    private fun startLocationExtrasListener(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("PERMISSION", "Location permission not granted", null)
            return
        }

        try {
            if (locationListener == null) {
                locationListener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        sendLocationExtras(location)
                    }
                }
            }

            val availableProviders = locationManager?.allProviders ?: emptyList()
            val preferredProviders = listOf(
                LocationManager.PASSIVE_PROVIDER,
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
            )

            for (provider in preferredProviders) {
                if (availableProviders.contains(provider)) {
                    locationManager?.requestLocationUpdates(
                        provider,
                        0L,
                        0f,
                        locationListener!!,
                        Looper.getMainLooper(),
                    )
                }
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to start location extras listener: ${e.message}", null)
        }
    }

    private fun stopLocationExtrasListener(result: MethodChannel.Result) {
        try {
            locationListener?.let {
                locationManager?.removeUpdates(it)
            }
            locationListener = null
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to stop location extras listener: ${e.message}", null)
        }
    }

    private fun sendLocationExtras(location: Location) {
        val extras = bundleToMap(location.extras)
        val satellites = extractInt(location.extras, "satellites")
        val hdop = extractDouble(location.extras, "hdop")
        val pdop = extractDouble(location.extras, "pdop")

        val locationExtrasMap = mutableMapOf<String, Any?>(
            "provider" to location.provider,
            "isMock" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                location.isMock
            } else {
                @Suppress("DEPRECATION")
                location.isFromMockProvider
            },
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "time" to location.time,
            "satellites" to satellites,
            "hdop" to hdop,
            "pdop" to pdop,
            "extras" to extras,
        )

        locationExtrasEventSink?.success(locationExtrasMap)
    }

    @Suppress("DEPRECATION")
    private fun extractInt(bundle: Bundle?, key: String): Int? {
        val value = bundle?.get(key) ?: return null
        return if (value is Number) value.toInt() else null
    }

    @Suppress("DEPRECATION")
    private fun extractDouble(bundle: Bundle?, key: String): Double? {
        val value = bundle?.get(key) ?: return null
        return if (value is Number) value.toDouble() else null
    }

    @Suppress("DEPRECATION")
    private fun bundleToMap(bundle: Bundle?): Map<String, Any?> {
        if (bundle == null) return emptyMap()

        val result = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            val value = bundle.get(key)
            result[key] = when (value) {
                null -> null
                is Boolean,
                is Int,
                is Long,
                is Double,
                is String -> value
                is Float -> value.toDouble()
                is Bundle -> bundleToMap(value)
                is IntArray -> value.toList()
                is LongArray -> value.toList()
                is FloatArray -> value.map { it.toDouble() }
                is DoubleArray -> value.toList()
                is BooleanArray -> value.toList()
                is Array<*> -> value.map { it?.toString() }
                else -> value.toString()
            }
        }

        return result
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

        gnssEventSink?.success(gnssStatusMap)
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        gnssEventSink = sink
    }

    fun setLocationExtrasEventSink(sink: EventChannel.EventSink?) {
        locationExtrasEventSink = sink
    }

    fun cleanup() {
        locationListener?.let {
            locationManager?.removeUpdates(it)
        }
        locationListener = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            gnssStatusCallback?.let {
                locationManager?.unregisterGnssStatusCallback(it)
            }
        }
        gnssStatusCallback = null
        gnssEventSink = null
        locationExtrasEventSink = null
    }
}
