package com.example.autoscroll_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class AutoScrollService : AccessibilityService() {

    companion object {
        private const val TAG = "AutoScrollService"
        const val ACTION_SCROLL = "com.example.autoscroll.SCROLL"
        var instance: AutoScrollService? = null
    }

    private val scrollReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
            if (intent?.action == ACTION_SCROLL) {
                performScroll()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        val filter = android.content.IntentFilter(ACTION_SCROLL)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scrollReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(scrollReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(scrollReceiver)
        if (instance == this) {
            instance = null
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        Log.d(TAG, "Accessibility Service Unbound")
        if (instance == this) {
            instance = null
        }
        return super.onUnbind(intent)
    }

    private var lastTargetAppState: Boolean = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: ""
        
        // CRITICAL: Ignore events from our own package.
        // If the overlay window gets focus, we don't want to hide it!
        if (packageName == this.packageName) return

        // We only care about major window state changes (switching apps or activities)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val isTargetApp = checkIsTargetApp(packageName)
            
            // Only send broadcast if the state actually changed
            if (isTargetApp != lastTargetAppState) {
                lastTargetAppState = isTargetApp
                notifyAppChange(isTargetApp)
            }
        }
    }

    private fun checkIsTargetApp(packageName: String): Boolean {
        return packageName == "com.instagram.android" || 
               packageName == "com.google.android.youtube"
    }

    private fun notifyAppChange(isTarget: Boolean) {
        val intent = android.content.Intent(AutoScrollPlugin.ACTION_APP_CHANGED)
        intent.putExtra(AutoScrollPlugin.EXTRA_IS_TARGET_APP, isTarget)
        intent.setPackage(packageName)
        sendBroadcast(intent)
        Log.d(TAG, "App changed: Target=$isTarget")
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    fun performScroll() {
        Log.d(TAG, "performScroll called")
        
        val displayMetrics = resources.displayMetrics
        val width = displayMetrics.widthPixels
        val height = displayMetrics.heightPixels

        // Define a longer swipe path (bottom-to-top) for better Reels reliability
        val path = Path()
        val startX = width / 2f
        val startY = height * 0.85f // Start near bottom
        val endY = height * 0.15f   // End near top

        path.moveTo(startX, startY)
        path.lineTo(startX, endY)

        val gestureBuilder = GestureDescription.Builder()
        // Use 400ms with a small 50ms start delay to make it feel more "natural" to the OS
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 50, 400))
        
        Log.d(TAG, "Dispatching Reels scroll gesture: ($startX, $startY) -> ($startX, $endY)")
        
        val dispatched = dispatchGesture(gestureBuilder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                Log.d(TAG, "Gesture Successfully Completed")
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                Log.e(TAG, "Gesture Cancelled - Screen might be off or overlay blocking")
            }
        }, null)

        if (!dispatched) {
            Log.e(TAG, "Failed to dispatch gesture - check service state")
        }
    }
}
