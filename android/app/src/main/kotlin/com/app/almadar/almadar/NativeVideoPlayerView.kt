package com.app.almadar.almadar

import android.content.Context
import android.net.Uri
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import android.app.Activity
import android.content.Intent
import android.os.Build
import android.util.Base64
import java.util.UUID

class NativeVideoPlayerView(context: Context, messenger: BinaryMessenger, id: Int, params: Map<String, Any>?) : PlatformView, MethodChannel.MethodCallHandler {
    // Removed hidden textureView to avoid black screen and conflict with PlayerView
    private val playerView: PlayerView = PlayerView(context)
    private val containerView: android.widget.FrameLayout = android.widget.FrameLayout(context).apply {
        setBackgroundColor(android.graphics.Color.BLACK)
        addView(playerView, android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT
        ))
    }
    private var exoPlayer: ExoPlayer
    private val methodChannel: MethodChannel = MethodChannel(messenger, "native_video_player_$id")
    private val context = context
    
    private var currentUserAgent: String? = null
    private var currentReferer: String? = null
    private var extraHeadersJson: String? = null
    private var currentUrl: String? = null
    private var currentDrmData: Map<String, String>? = null
    
    private var sources: List<Map<String, Any>> = listOf()
    private var currentSourceIndex: Int = 0

    private fun createHttpDataSourceFactory(userAgent: String?, referer: String?, extraHeaders: String?): androidx.media3.datasource.DefaultHttpDataSource.Factory {
        val finalUserAgent = if (!userAgent.isNullOrEmpty()) userAgent else "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        
        val factory = androidx.media3.datasource.DefaultHttpDataSource.Factory()
            .setUserAgent(finalUserAgent)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(20000)
            .setReadTimeoutMs(20000)
        
        val headers = mutableMapOf<String, String>()
        if (!referer.isNullOrEmpty()) {
            headers["Referer"] = referer
        }
        
        if (!extraHeaders.isNullOrEmpty()) {
            try {
                val json = org.json.JSONObject(extraHeaders)
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    headers[key] = json.getString(key)
                }
            } catch (e: Exception) {
                println("NativePlayer: Error parsing extra headers: $e")
            }
        }
        
        if (headers.isNotEmpty()) {
            factory.setDefaultRequestProperties(headers)
        }
        
        println("NativePlayer: DataSource created. UA: $finalUserAgent, Referer: $referer, ExtraHeaders: $extraHeaders")
        return factory
    }
    
    private var httpDataSourceFactory = createHttpDataSourceFactory(null, null, null)
    private var dataSourceFactory = androidx.media3.datasource.DefaultDataSource.Factory(context, httpDataSourceFactory)

    init {
        val loadControl = androidx.media3.exoplayer.DefaultLoadControl.Builder()
            .setBufferDurationsMs(5000, 15000, 1500, 2000)
            .setBackBuffer(0, false) 
            .build()

        val renderersFactory = androidx.media3.exoplayer.DefaultRenderersFactory(context)
            .setExtensionRendererMode(androidx.media3.exoplayer.DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)

        exoPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setLoadControl(loadControl)
            .build()

        // Let PlayerView manage the surface automatically
        playerView.player = exoPlayer
        playerView.useController = false
        playerView.resizeMode = androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FILL
        
        val audioAttributes = androidx.media3.common.AudioAttributes.Builder()
            .setUsage(androidx.media3.common.C.USAGE_MEDIA)
            .setContentType(androidx.media3.common.C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()
        exoPlayer.setAudioAttributes(audioAttributes, true)

        methodChannel.setMethodCallHandler(this)
        
        exoPlayer.addListener(object : androidx.media3.common.Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                methodChannel.invokeMethod("onPlaybackState", mapOf("state" to state))
                println("NativePlayer: State changed to $state")
            }

            override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
                val resolutions = mutableSetOf<Int>()
                for (group in tracks.groups) {
                    if (group.type == androidx.media3.common.C.TRACK_TYPE_VIDEO) {
                        for (i in 0 until group.length) {
                            val format = group.getTrackFormat(i)
                            if (format.height > 0) {
                                resolutions.add(format.height)
                            }
                        }
                    }
                }
                
                if (resolutions.isNotEmpty()) {
                    val sortedQualities = resolutions.sortedDescending().map { "${it}p" }
                    println("NativePlayer: Broad-casting found qualities: $sortedQualities")
                    methodChannel.invokeMethod("onAvailableQualities", mapOf("qualities" to sortedQualities))
                } else {
                    println("NativePlayer: No video resolutions found in tracks")
                    methodChannel.invokeMethod("onAvailableQualities", mapOf("qualities" to emptyList<String>()))
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                println("NativePlayer: Detailed Error: ${error.errorCodeName} - ${error.message}")
                if (currentSourceIndex < sources.size - 1) {
                    currentSourceIndex++
                    println("NativePlayer: Switching to fallback #${currentSourceIndex}")
                    prepareSource(sources[currentSourceIndex])
                } else {
                    methodChannel.invokeMethod("onError", mapOf("message" to (error.message ?: "Playback failed")))
                }
            }
        })
        
        params?.let { p ->
            (p["sources"] as? List<Map<String, Any>>)?.let { playList(it) } ?:
            (p["url"] as? String)?.let { play(it, p["drmData"] as? Map<String, String>, null, p["userAgent"] as? String, p["referer"] as? String) }
        }
    }

    override fun getView(): View = containerView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val sourcesArg = call.argument<List<Map<String, Any>>>("sources")
                if (sourcesArg != null) playList(sourcesArg)
                else play(call.argument("url") ?: "", call.argument("drmData"), call.argument("quality"), call.argument("userAgent"), call.argument("referer"))
                result.success(null)
            }
            "pause" -> { exoPlayer.pause(); result.success(null) }
            "resume" -> { exoPlayer.play(); result.success(null) }
            "stop" -> { exoPlayer.stop(); result.success(null) }
            "getPosition" -> result.success(exoPlayer.currentPosition)
            "getDuration" -> result.success(if (exoPlayer.duration < 0) 0L else exoPlayer.duration)
            "seekTo" -> {
                val pos = (call.argument<Any>("position") as? Number)?.toLong() ?: 0L
                exoPlayer.seekTo(pos)
                result.success(null)
            }
            "setResizeMode" -> {
                val mode = call.argument<Int>("mode") ?: 0
                playerView.resizeMode = when(mode) {
                    1 -> androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FILL
                    3 -> androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                    else -> androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT
                }
                result.success(null)
            }
            "startCast" -> {
                try {
                    val intent = Intent("android.settings.CAST_SETTINGS")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CAST_ERR", e.message, null)
                }
            }
            "dispose" -> { 
                dispose()
                result.success(null) 
            }
        }
    }

    private fun playList(sourceList: List<Map<String, Any>>) {
        this.sources = sourceList.filter { (it["url"] as? String)?.startsWith("http", true) == true }
        if (this.sources.isEmpty()) {
            methodChannel.invokeMethod("onError", mapOf("message" to "No valid URL"))
            return
        }
        currentSourceIndex = 0
        prepareSource(sources[currentSourceIndex])
    }

    private fun prepareSource(source: Map<String, Any>) {
        val url = source["url"] as? String ?: return
        val drmType = source["drmType"] as? String
        val drmKey = source["drmKey"] as? String
        val drmLicenseUrl = source["drmLicenseUrl"] as? String

        // Parse all headers from the JSON string first
        val headersJson = source["headers"] as? String
        val parsedHeaders = mutableMapOf<String, String>()
        if (!headersJson.isNullOrEmpty()) {
            try {
                val json = org.json.JSONObject(headersJson)
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    parsedHeaders[key] = json.getString(key)
                }
            } catch (e: Exception) {
                println("NativePlayer: Error parsing headers JSON: $e")
            }
        }

        // User-Agent: prefer explicit field, fall back to headers map
        val userAgent = (source["userAgent"] as? String)?.takeIf { it.isNotEmpty() }
            ?: parsedHeaders["User-Agent"]
            ?: parsedHeaders["user-agent"]

        // Referer: prefer explicit field, fall back to headers map
        val referer = (source["Referer"] as? String)?.takeIf { it.isNotEmpty() }
            ?: (source["referer"] as? String)?.takeIf { it.isNotEmpty() }
            ?: parsedHeaders["Referer"]
            ?: parsedHeaders["referer"]

        println("NativePlayer: Preparing $url")
        println("NativePlayer: UserAgent=$userAgent | Referer=$referer | ExtraHeaders=$parsedHeaders")

        // Build the final factory using resolved values
        val finalUserAgent = if (!userAgent.isNullOrEmpty()) userAgent
            else "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

        val factory = androidx.media3.datasource.DefaultHttpDataSource.Factory()
            .setUserAgent(finalUserAgent)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(20000)
            .setReadTimeoutMs(20000)

        val requestHeaders = mutableMapOf<String, String>()
        // Add all parsed headers first (lower priority)
        requestHeaders.putAll(parsedHeaders)
        // Override with explicit referer (higher priority)
        if (!referer.isNullOrEmpty()) requestHeaders["Referer"] = referer

        if (requestHeaders.isNotEmpty()) {
            factory.setDefaultRequestProperties(requestHeaders)
        }

        httpDataSourceFactory = factory
        dataSourceFactory = androidx.media3.datasource.DefaultDataSource.Factory(context, httpDataSourceFactory)

        val mediaItemBuilder = MediaItem.Builder().setUri(url)

        // Accurate MIME detection
        val lowerUrl = url.lowercase()
        if (lowerUrl.contains(".m3u8") || lowerUrl.contains("m3u")) {
            mediaItemBuilder.setMimeType(androidx.media3.common.MimeTypes.APPLICATION_M3U8)
        } else if (lowerUrl.contains(".mpd") || lowerUrl.contains("dash")) {
            mediaItemBuilder.setMimeType(androidx.media3.common.MimeTypes.APPLICATION_MPD)
        }

        var drmSessionManager: androidx.media3.exoplayer.drm.DrmSessionManager? = null
        if (!drmType.isNullOrEmpty()) {
            println("NativePlayer: Config DRM Type: $drmType")
            if (drmType == "widevine" && !drmLicenseUrl.isNullOrEmpty()) {
                mediaItemBuilder.setDrmConfiguration(MediaItem.DrmConfiguration.Builder(androidx.media3.common.C.WIDEVINE_UUID).setLicenseUri(drmLicenseUrl).build())
            } else if (drmType == "clearkey" && !drmKey.isNullOrEmpty()) {
                val kidB64 = toBase64Url(if (drmKey.contains(":")) drmKey.split(":")[0] else "")
                val keyB64 = toBase64Url(if (drmKey.contains(":")) drmKey.split(":")[1] else drmKey)
                val clearKeyJson = """{"keys":[{"kty":"oct","k":"$keyB64","kid":"$kidB64"}],"type":"temporary"}"""
                drmSessionManager = androidx.media3.exoplayer.drm.DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(androidx.media3.common.C.CLEARKEY_UUID, androidx.media3.exoplayer.drm.FrameworkMediaDrm.DEFAULT_PROVIDER)
                    .build(androidx.media3.exoplayer.drm.LocalMediaDrmCallback(clearKeyJson.toByteArray()))
                mediaItemBuilder.setDrmConfiguration(MediaItem.DrmConfiguration.Builder(androidx.media3.common.C.CLEARKEY_UUID).build())
            }
        }

        val mediaSourceFactory = androidx.media3.exoplayer.source.DefaultMediaSourceFactory(dataSourceFactory)
        drmSessionManager?.let { manager -> mediaSourceFactory.setDrmSessionManagerProvider { manager } }

        exoPlayer.stop()
        exoPlayer.clearMediaItems()
        exoPlayer.setMediaSource(mediaSourceFactory.createMediaSource(mediaItemBuilder.build()))
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    private fun play(url: String, drmData: Map<String, String>?, quality: String?, userAgent: String?, referer: String?) {
        println("NativePlayer: Playing $url with DRM: ${drmData?.get("type")}")
        currentUrl = url
        currentDrmData = drmData
        
        httpDataSourceFactory = createHttpDataSourceFactory(userAgent, referer, null)
        dataSourceFactory = androidx.media3.datasource.DefaultDataSource.Factory(context, httpDataSourceFactory)
        
        val mediaItemBuilder = MediaItem.Builder().setUri(url)
        val lowerUrl = url.lowercase()
        if (lowerUrl.contains(".m3u8") || lowerUrl.contains("hls")) mediaItemBuilder.setMimeType(androidx.media3.common.MimeTypes.APPLICATION_M3U8)
        else if (lowerUrl.contains(".mpd")) mediaItemBuilder.setMimeType(androidx.media3.common.MimeTypes.APPLICATION_MPD)

        var drmManager: androidx.media3.exoplayer.drm.DrmSessionManager? = null
        drmData?.let { drm ->
            val type = drm["type"] ?: ""
            if (type == "widevine") {
                drm["licenseUrl"]?.let { mediaItemBuilder.setDrmConfiguration(MediaItem.DrmConfiguration.Builder(androidx.media3.common.C.WIDEVINE_UUID).setLicenseUri(it).build()) }
            } else if (type == "clearkey") {
                val keyData = drm["key"] ?: ""
                val kidB64 = toBase64Url(if (keyData.contains(":")) keyData.split(":")[0] else "")
                val keyB64 = toBase64Url(if (keyData.contains(":")) keyData.split(":")[1] else keyData)
                val json = """{"keys":[{"kty":"oct","k":"$keyB64","kid":"$kidB64"}],"type":"temporary"}"""
                drmManager = androidx.media3.exoplayer.drm.DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(androidx.media3.common.C.CLEARKEY_UUID, androidx.media3.exoplayer.drm.FrameworkMediaDrm.DEFAULT_PROVIDER)
                    .build(androidx.media3.exoplayer.drm.LocalMediaDrmCallback(json.toByteArray()))
                mediaItemBuilder.setDrmConfiguration(MediaItem.DrmConfiguration.Builder(androidx.media3.common.C.CLEARKEY_UUID).build())
            }
        }

        val factory = androidx.media3.exoplayer.source.DefaultMediaSourceFactory(dataSourceFactory)
        drmManager?.let { manager -> factory.setDrmSessionManagerProvider { manager } }
        exoPlayer.setMediaSource(factory.createMediaSource(mediaItemBuilder.build()))
        applyQuality(quality)
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    private fun applyQuality(preferredQuality: String?) {
        val params = exoPlayer.trackSelectionParameters.buildUpon()
        if (preferredQuality != null && preferredQuality != "Auto") {
            val height = preferredQuality.replace("p", "").toIntOrNull() ?: 0
            params.setMaxVideoSize(1920, height).setMinVideoSize(0, height)
        } else {
            params.clearVideoSizeConstraints()
        }
        exoPlayer.trackSelectionParameters = params.build()
    }

    private fun toBase64Url(hexOrString: String): String {
        if (hexOrString.isEmpty()) return ""
        val clean = hexOrString.replace(" ", "").replace("-", "")
        val bytes = if (clean.matches(Regex("^[0-9a-fA-F]+$"))) {
            clean.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        } else {
            clean.toByteArray()
        }
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    override fun dispose() {
        playerView.player = null
        exoPlayer.stop()
        exoPlayer.clearMediaItems()
        exoPlayer.release()
        methodChannel.setMethodCallHandler(null)
    }
}
