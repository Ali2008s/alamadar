package com.app.almadar.almadar

/**
 * Kotlin bridge to the native C++ security library (libalmadar_guard.so).
 * The actual logic runs inside native compiled code — not readable via DEX editors
 * or tools like MT Manager.
 */
object NativeSecurityGuard {

    init {
        // Load the native library compiled from security_guard.cpp
        System.loadLibrary("almadar_guard")
    }

    /**
     * Pass the app's PackageManager to native code which checks for blocked apps.
     * Returns true if any blocked/piracy/patching app is installed.
     */
    external fun checkBlockedApps(packageManager: android.content.pm.PackageManager): Boolean

    /**
     * Check common root paths using native file access (harder to hook than Java File.exists).
     * Returns true if device appears to be rooted.
     */
    external fun checkRootPaths(): Boolean
    
    /**
     * Basic String Encryption via C++
     */
    external fun encryptData(data: ByteArray): ByteArray
    
    /**
     * Basic String Decryption via C++
     */
    external fun decryptData(data: ByteArray): ByteArray
}
