package com.bringingfire.rich_clipboard

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class RichClipboardPlugin : FlutterPlugin, MethodCallHandler {
    private companion object {
        const val MIME_TEXT_PLAIN = "text/plain"
        const val MIME_TEXT_HTML = "text/html"
        const val MIME_QUILL_DELTA_JSON = "application/vnd.quill.delta+json"
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.bringingfire.rich_clipboard")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getAvailableTypes" -> {
                getAvailableTypes(result)
            }
            "getData" -> {
                getData(result)
            }
            "setData" -> {
                setData(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    private fun getAvailableTypes(@NonNull result: Result) {
        val clipboard = context!!.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        if (clip == null || clip.itemCount < 1) {
            result.success(emptyList<String>())
            return
        }
        val mimeTypes = clip.description.filterMimeTypes("*/*").toList()
        result.success(mimeTypes)
    }

    private fun getData(@NonNull result: Result) {
        val clipboard = context!!.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        if (clip == null || clip.itemCount < 1) {
            result.success(emptyMap<String, String>())
            return
        }

        val output = mutableMapOf<String, String>()
        for (i in 0 until clip.itemCount) {
            val item = clip.getItemAt(i)
            if (item.text != null) {
                output[MIME_TEXT_PLAIN] = item.text.toString()
            }
            if (item.htmlText != null) {
                output[MIME_TEXT_HTML] = item.htmlText.toString()
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val deltaJson = clip.description.extras?.getString(MIME_QUILL_DELTA_JSON)
            if (!deltaJson.isNullOrEmpty()) {
                output[MIME_QUILL_DELTA_JSON] = deltaJson
            }
        }

        result.success(output)
    }

    private fun setData(@NonNull call: MethodCall, @NonNull result: Result) {
        val args = call.arguments<Map<String, String?>>() ?: emptyMap()
        val plainText = args[MIME_TEXT_PLAIN]
        val htmlText = args[MIME_TEXT_HTML]
        val quillDeltaJson = args[MIME_QUILL_DELTA_JSON]
        val clipboard = context!!.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        }

        val clip = when {
            plainText != null && htmlText != null ->
                ClipData.newHtmlText(MIME_TEXT_PLAIN, plainText, htmlText)
            plainText != null ->
                ClipData.newPlainText(MIME_TEXT_PLAIN, plainText)
            htmlText != null ->
                ClipData.newHtmlText(MIME_TEXT_PLAIN, htmlText, htmlText)
            quillDeltaJson != null ->
                ClipData(
                    ClipDescription(
                        MIME_TEXT_PLAIN,
                        arrayOf(MIME_TEXT_PLAIN, MIME_QUILL_DELTA_JSON)
                    ),
                    ClipData.Item(quillDeltaJson)
                )
            else -> null
        }

        if (clip != null) {
            if (quillDeltaJson != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val extras = clip.description.extras ?: PersistableBundle()
                    extras.putString(MIME_QUILL_DELTA_JSON, quillDeltaJson)
                    clip.description.extras = extras
                }
            }
            clipboard.setPrimaryClip(clip)
        }

        result.success(null)
    }
}