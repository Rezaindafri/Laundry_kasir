package com.example.laundry_management_system

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val whatsappReceiptChannel =
        "com.example.laundry_management_system/whatsapp_receipt"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            whatsappReceiptChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "openReceiptChat") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val phone = call.argument<String>("phone")
            val image = call.argument<ByteArray>("image")
            val message = call.argument<String>("message") ?: ""
            val filename = call.argument<String>("filename") ?: "bon-laundry.png"
            if (phone.isNullOrBlank() || image == null) {
                result.success(false)
                return@setMethodCallHandler
            }

            try {
                val receiptDirectory = File(cacheDir, "receipts")
                if (!receiptDirectory.exists() && !receiptDirectory.mkdirs()) {
                    result.error("FILE_ERROR", "Folder bon tidak dapat dibuat.", null)
                    return@setMethodCallHandler
                }
                val safeFilename = filename.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val receiptFile = File(receiptDirectory, safeFilename)
                receiptFile.outputStream().use { it.write(image) }
                val uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    receiptFile,
                )
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, message)
                    // WhatsApp uses this recipient identifier when it is
                    // available. If its version ignores it, the attachment
                    // still opens inside WhatsApp ready to be sent.
                    putExtra("jid", "$phone@s.whatsapp.net")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                val whatsappPackage = listOf("com.whatsapp", "com.whatsapp.w4b")
                    .firstOrNull { packageName ->
                        Intent(shareIntent).setPackage(packageName)
                            .resolveActivity(packageManager) != null
                    }

                if (whatsappPackage != null) {
                    startActivity(Intent(shareIntent).setPackage(whatsappPackage))
                } else {
                    // Behave like Android Gallery's Share action when a
                    // WhatsApp variant cannot be identified. The image stays
                    // attached and the user can choose WhatsApp manually.
                    val chooserIntent = Intent(shareIntent).apply {
                        removeExtra("jid")
                    }
                    startActivity(Intent.createChooser(chooserIntent, "Kirim bon melalui"))
                }
                result.success(true)
            } catch (error: Exception) {
                result.error("WHATSAPP_ERROR", error.message, null)
            }
        }
    }
}
