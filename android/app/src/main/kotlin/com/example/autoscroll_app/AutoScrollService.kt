package com.example.autoscroll_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Path
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AutoScrollService : AccessibilityService() {

    companion object {
        private const val TAG = "AutoScrollService"
        const val ACTION_SCROLL = "com.example.autoscroll.SCROLL"
        var instance: AutoScrollService? = null
    }

    // =========================
    // Scroll Receiver
    // =========================
    private val scrollReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_SCROLL) {
                performScroll()
            }
        }
    }

    // =========================
    // Audio
    // =========================
    private lateinit var audioManager: AudioManager
    private val audioHandler = Handler(Looper.getMainLooper())

    // =========================
    // State
    // =========================
    private var isAudioActiveCached = false
    private var lastTargetAppState = false
    private var lastPackageName = ""

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

    // =========================
    // Lifecycle
    // =========================
    override fun onCreate() {
        super.onCreate()
        instance = this

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        val filter = IntentFilter(ACTION_SCROLL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scrollReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(scrollReceiver, filter)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")
        instance = this

        isAudioActiveCached = audioManager.isMusicActive
        startAudioPolling()
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(scrollReceiver)
        stopAudioPolling()
        instance = null
    }

    override fun onUnbind(intent: Intent?): Boolean {
        stopAudioPolling()
        instance = null
        return super.onUnbind(intent)
    }

    // =========================
    // Accessibility
    // =========================
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventPackageName = event.packageName?.toString() ?: ""
        if (eventPackageName == packageName) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val currentPackage =
                rootInActiveWindow?.packageName?.toString() ?: eventPackageName

            if (currentPackage.isEmpty() || currentPackage == lastPackageName) return
            lastPackageName = currentPackage

            val isTarget = checkIsTargetApp(currentPackage)
            val isIgnored = isInputMethodApp(currentPackage)

            Log.d(TAG, "App Switch → $currentPackage | target=$isTarget")

            if (isTarget) {
                lastTargetAppState = true
                notifyStateChange(true)
            } else if (!isIgnored) {
                lastTargetAppState = false
                notifyStateChange(false)
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility interrupted")
    }

    // =========================
    // Audio polling (SAFE)
    // =========================
    private val audioPollRunnable = object : Runnable {
        override fun run() {
            updateAudioState()
            audioHandler.postDelayed(this, 800)
        }
    }

    private fun startAudioPolling() {
        audioHandler.post(audioPollRunnable)
    }

    private fun stopAudioPolling() {
        audioHandler.removeCallbacks(audioPollRunnable)
    }

    private fun updateAudioState() {
        val active = audioManager.isMusicActive
        if (active != isAudioActiveCached) {
            isAudioActiveCached = active
            Log.i(TAG, "Audio active = $active")

            if (lastTargetAppState) {
                notifyStateChange(true)
            }
        }
    }

    // =========================
    // Helpers
    // =========================
    private fun isInputMethodApp(packageName: String): Boolean {
        val lower = packageName.lowercase()
        return ignoredPackages.contains(packageName) ||
                lower.contains("inputmethod") ||
                lower.contains("keyboard")
    }

    private fun checkIsTargetApp(packageName: String): Boolean {
        val lower = packageName.lowercase()
        return targetPackages.contains(packageName) ||
                lower.contains("instagram") ||
                lower.contains("youtube") ||
                lower.contains("tiktok") ||
                lower.contains("reels")
    }

    private fun notifyStateChange(isTarget: Boolean) {
        val intent = Intent(AutoScrollPlugin.ACTION_APP_CHANGED)
        intent.putExtra(AutoScrollPlugin.EXTRA_IS_TARGET_APP, isTarget)
        intent.putExtra(AutoScrollPlugin.EXTRA_PACKAGE_NAME, lastPackageName)
        intent.putExtra(
            AutoScrollPlugin.EXTRA_IS_MUSIC_ACTIVE,
            isAudioActiveCached
        )
        intent.setPackage(packageName)
        sendBroadcast(intent)

        Log.d(
            TAG,
            "Broadcast → target=$isTarget pkg=$lastPackageName audio=$isAudioActiveCached"
        )
    }

    // =========================
    // Scroll
    // =========================
    fun performScroll() {
        val metrics = resources.displayMetrics
        val path = Path().apply {
            moveTo(metrics.widthPixels * 0.5f, metrics.heightPixels * 0.8f)
            lineTo(metrics.widthPixels * 0.5f, metrics.heightPixels * 0.2f)
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 10, 350))
            .build()

        dispatchGesture(gesture, null, null)
    }
}
