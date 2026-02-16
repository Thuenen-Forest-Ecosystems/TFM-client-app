package de.thuenen.terrestrial_forest_monitor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var gnssHandler: GnssChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize GNSS handler
        gnssHandler = GnssChannelHandler(this)

        // Setup method channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelHandler.METHOD_CHANNEL
        ).setMethodCallHandler(gnssHandler)

        // Setup event channel
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelHandler.EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                gnssHandler?.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                gnssHandler?.setEventSink(null)
            }
        })
    }

    override fun onDestroy() {
        gnssHandler?.cleanup()
        super.onDestroy()
    }
}
