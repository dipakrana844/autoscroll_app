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

    private val targetPackages = setOf(
        "com.instagram.android",
        "com.google.android.youtube",
        "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill",
        "com.facebook.katana",
        "com.facebook.orca"
    )

    private val ignoredPackages = setOf(
        "com.google.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        "com.microsoft.emmx"
    )

    private var lastTargetAppState: Boolean = false
    private var lastPackageName: String = ""

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventPackageName = event.packageName?.toString() ?: ""
        
        // 1. Ignore events from our own package to prevent self-hiding
        if (eventPackageName == this.packageName) return

        // 2. Only respond to major window changes (App/Activity switches)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            // Get the package name of the actual active window
            val currentPackageName = rootInActiveWindow?.packageName?.toString() ?: eventPackageName
            if (currentPackageName.isEmpty()) return

            // 3. Prevent logic from running if the package hasn't changed (prevents spam)
            if (currentPackageName == lastPackageName) return
            lastPackageName = currentPackageName

            val isTarget = checkIsTargetApp(currentPackageName)
            val isIgnored = isInputMethodApp(currentPackageName)

            Log.d(TAG, "App Switch -> Active: $currentPackageName, IsTarget: $isTarget, IsIgnored: $isIgnored")

            if (isTarget) {
                // If we entered a target app, ensure overlay is shown
                if (!lastTargetAppState) {
                    lastTargetAppState = true
                    notifyAppChange(true)
                }
            } else if (!isIgnored) {
                // FORCE hide whenever we move to a different, non-target app (like Chrome/Launcher/SystemUI)
                // This now properly handles Home screen and Recents menu by closing the overlay.
                lastTargetAppState = false
                notifyAppChange(false)
            }
        }
    }

    private fun isInputMethodApp(packageName: String): Boolean {
        val lower = packageName.lowercase()
        return ignoredPackages.contains(packageName) || 
               lower.contains("inputmethod") || 
               lower.contains("keyboard")
    }

    private fun checkIsTargetApp(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        
        val lower = packageName.lowercase()
        // Direct target package check
        if (targetPackages.contains(packageName)) return true
        
        // Keyword check for variants/modified versions
        return lower.contains("instagram") || 
               lower.contains("youtube") || 
               lower.contains("tiktok") ||
               lower.contains("reels")
    }

    private fun notifyAppChange(isTarget: Boolean) {
        val intent = android.content.Intent(AutoScrollPlugin.ACTION_APP_CHANGED)
        intent.putExtra(AutoScrollPlugin.EXTRA_IS_TARGET_APP, isTarget)
        intent.putExtra(AutoScrollPlugin.EXTRA_PACKAGE_NAME, lastPackageName)
        
        val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
        val isMusicActive = audioManager.isMusicActive
        intent.putExtra(AutoScrollPlugin.EXTRA_IS_MUSIC_ACTIVE, isMusicActive)

        intent.setPackage(packageName)
        sendBroadcast(intent)
        Log.d(TAG, "Broadcast sent: isTarget=$isTarget, pkg=$lastPackageName, music=$isMusicActive")
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    fun performScroll() {
        Log.d(TAG, "performScroll initiated")
        
        val displayMetrics = resources.displayMetrics
        val width = displayMetrics.widthPixels
        val height = displayMetrics.heightPixels

        // Optimized swipe path for Short-form video apps (Reels/Shorts)
        val path = Path()
        val startX = width * 0.5f
        val startY = height * 0.8f // Start near bottom (but not off-screen)
        val endY = height * 0.2f   // End near top

        path.moveTo(startX, startY)
        // Add a slight curve or multi-point line if needed, but straight is usually best for scrolls
        path.lineTo(startX, endY)

        val gestureBuilder = GestureDescription.Builder()
        // 350ms is a good balance between "too fast" and "too slow"
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 10, 350))
        
        val dispatched = dispatchGesture(gestureBuilder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                Log.d(TAG, "Gesture execution successfully completed")
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                Log.e(TAG, "Gesture execution cancelled")
            }
        }, null)

        if (!dispatched) {
            Log.e(TAG, "Critical: Failed to dispatch gesture")
        }
    }
}
