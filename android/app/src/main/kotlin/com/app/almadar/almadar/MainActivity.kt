package com.app.almadar.almadar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.os.Debug
import android.provider.Settings
import android.view.WindowManager
import android.view.View
import android.media.AudioManager
import android.content.Context
import java.net.NetworkInterface
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.almadar.security"
    private val VOLUME_CHANNEL = "com.almadar.volume"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Native Video Player
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "native_video_player_view",
            NativeVideoPlayerFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        // ── Security channel ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurity" -> {
                    result.success(isDeviceCompromised())
                }
                "encrypt" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        try {
                            val encrypted = NativeSecurityGuard.encryptData(data)
                            result.success(encrypted)
                        } catch (e: Exception) {
                            result.error("ENCRYPT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Data cannot be null", null)
                    }
                }
                "decrypt" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        try {
                            val decrypted = NativeSecurityGuard.decryptData(data)
                            result.success(decrypted)
                        } catch (e: Exception) {
                            result.error("DECRYPT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Data cannot be null", null)
                    }
                }
                "setDisplayCutoutMode" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    enableDisplayCutout(enabled)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // ── Volume / Brightness channel ───────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "getVolume" -> {
                    val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble()
                    val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).toDouble()
                    result.success(if (max > 0) current / max else 0.0)
                }
                "setVolume" -> {
                    val value = (call.argument<Double>("value") ?: 1.0)
                    val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val vol = (value * max).toInt().coerceIn(0, max)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, vol, 0)
                    result.success(null)
                }
                "setBrightness" -> {
                    val value = (call.argument<Double>("value") ?: 0.5).toFloat()
                    try {
                        val lp = window.attributes
                        lp.screenBrightness = value.coerceIn(0.01f, 1.0f)
                        window.attributes = lp
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BRIGHTNESS_ERROR", e.message, null)
                    }
                }
                "requestPermissions" -> {
                    // No special permissions needed for stream volume / window brightness
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enableDisplayCutout(enable: Boolean) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            val window = this.window
            val layoutParams = window.attributes
            if (enable) {
                layoutParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                
                // Set flags for fullscreen and immersive sticky
                window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )

                // Re-hide system bars if they reappear (for versions < Android 11)
                window.decorView.setOnSystemUiVisibilityChangeListener { visibility ->
                    if (visibility and View.SYSTEM_UI_FLAG_FULLSCREEN == 0) {
                        window.decorView.systemUiVisibility = (
                            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        )
                    }
                }
            } else {
                layoutParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT
                window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
                window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
                window.decorView.setOnSystemUiVisibilityChangeListener(null)
            }
            window.attributes = layoutParams
        }
    }

    private fun isDeviceCompromised(): Boolean {
        return hasPiracyApps() || isProxyEnabled() || isVpnConnected()
    }

    private fun isProxyEnabled(): Boolean {
        val proxyAddress = System.getProperty("http.proxyHost")
        val proxyPort = System.getProperty("http.proxyPort")
        return !proxyAddress.isNullOrEmpty() && !proxyPort.isNullOrEmpty()
    }

    private fun isVpnConnected(): Boolean {
        try {
            val networks = NetworkInterface.getNetworkInterfaces()
            for (network in networks) {
                if (network.isUp && (network.name.contains("tun") || network.name.contains("ppp") || network.name.contains("pptp"))) {
                    return true
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
        return false
    }

    /**
     * Delegates blocked-app detection to the native C++ library (libalmadar_guard.so).
     * The package list lives inside the compiled .so file — not visible in DEX/SMALI
     * and cannot be removed via tools like MT Manager without recompiling native code.
     */
    private fun hasPiracyApps(): Boolean {
        return try {
            NativeSecurityGuard.checkBlockedApps(packageManager)
        } catch (e: Throwable) {
            // If native library fails for any reason, fall back to safe mode
            false
        }
    }

}
