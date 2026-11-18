package de.thuenen.terrestrial_forest_monitor

import android.app.Activity
import android.os.Build
import android.view.ViewTreeObserver
import android.view.WindowInsets
import io.flutter.plugin.common.EventChannel

/**
 * Reports how far the soft keyboard covers the bottom of the app *without*
 * Android reporting it as an IME inset (#505).
 *
 * Case: system bars hidden (immersive, e.g. by device policy on the Galaxy Tab
 * Active5 Pro) + Samsung keyboard in floating mode. The IME inset is then 0, but
 * the keyboard window paints an opaque strip over the area of the hidden
 * navigation bar. Flutter sees neither viewInsets nor padding for that strip,
 * so the last table row ends up behind it.
 *
 * Emits the overlap in physical pixels (0 when nothing is covered), only on change.
 */
class ImeOverlapHandler(private val activity: Activity) : EventChannel.StreamHandler {
    companion object {
        const val EVENT_CHANNEL = "com.thuenen.tfm/ime_overlap"
    }

    private var sink: EventChannel.EventSink? = null
    private var lastValue = -1
    private val listener = ViewTreeObserver.OnGlobalLayoutListener { emit() }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        lastValue = -1
        activity.window.decorView.viewTreeObserver.addOnGlobalLayoutListener(listener)
        emit()
    }

    override fun onCancel(arguments: Any?) {
        activity.window.decorView.viewTreeObserver.removeOnGlobalLayoutListener(listener)
        sink = null
    }

    private fun emit() {
        val value = try {
            computeOverlap()
        } catch (e: Exception) {
            0 // never let a layout listener crash the app
        }
        if (value == lastValue) return
        lastValue = value
        sink?.success(value)
    }

    private fun computeOverlap(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return 0
        val decor = activity.window.decorView
        val insets = decor.rootWindowInsets ?: return 0
        val ime = WindowInsets.Type.ime()
        val nav = WindowInsets.Type.navigationBars()
        if (!insets.isVisible(ime)) return 0
        // Docked keyboard: reported as IME inset -> Flutter viewInsets handle it.
        if (insets.getInsets(ime).bottom > 0) return 0
        // Visible navigation bar: already part of Flutter's padding.
        if (insets.isVisible(nav)) return 0

        // Floating keyboard over a hidden navigation bar. In Samsung's
        // full-screen (freeform) mode the app window gets no navigation-bar
        // insets at all, so take the bar height from the display metrics and
        // count only the part that actually lies under this window.
        val navHeight = navigationBarHeight()
        if (navHeight <= 0) return 0
        val displayBottom = activity.windowManager.maximumWindowMetrics.bounds.bottom
        val loc = IntArray(2)
        decor.getLocationOnScreen(loc)
        val windowBottom = loc[1] + decor.height
        return (windowBottom - (displayBottom - navHeight)).coerceIn(0, navHeight)
    }

    private fun navigationBarHeight(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val fromMetrics = activity.windowManager.maximumWindowMetrics.windowInsets
                .getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars()).bottom
            if (fromMetrics > 0) return fromMetrics
        }
        val res = activity.resources
        val id = res.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (id > 0) res.getDimensionPixelSize(id) else 0
    }
}
