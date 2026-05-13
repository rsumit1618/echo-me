package com.sr.echo_me

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "echo_me/attachments"
    private val pickPdfRequestCode = 4701
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPdf" -> pickPdf(result)
                "openFile" -> openFile(call.arguments as? String, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickPdf(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("pick_in_progress", "A PDF picker is already open.", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
        }
        startActivityForResult(intent, pickPdfRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickPdfRequestCode) return

        val result = pendingPickResult
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK) {
            result?.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result?.success(null)
            return
        }

        try {
            val file = copyPdfToCache(uri)
            result?.success(file.absolutePath)
        } catch (error: Exception) {
            result?.error("pdf_copy_failed", error.message, null)
        }
    }

    private fun copyPdfToCache(uri: Uri): File {
        val file = File(cacheDir, "echo_pdf_${System.currentTimeMillis()}.pdf")
        contentResolver.openInputStream(uri).use { input ->
            FileOutputStream(file).use { output ->
                input?.copyTo(output)
            }
        }
        return file
    }

    private fun openFile(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("missing_path", "File path is required.", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("missing_file", "File does not exist.", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Open PDF"))
        result.success(null)
    }
}
