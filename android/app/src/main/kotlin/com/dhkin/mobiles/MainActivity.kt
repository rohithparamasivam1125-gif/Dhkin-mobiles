package com.dhkin.mobiles

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.media.AudioManager

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.dhkin_mobiles.share/whatsapp"
    private val SOUND_CHANNEL = "com.dhkin_mobiles.sound/play"
    private val INSTALLER_CHANNEL = "com.dhkin_mobiles.app/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Installer Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "installDownloadedApk" -> {
                    try {
                        val fileName = call.argument<String>("fileName") ?: "dhkin_mobiles_update.apk"
                        val apkFile = File(getExternalFilesDir(null), fileName)
                        if (apkFile.exists()) {
                            val apkUri: Uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apkFile
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("FILE_NOT_FOUND", "APK file not found at ${apkFile.absolutePath}", null)
                        }
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Share Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sharePdfDirect") {
                val phone = call.argument<String>("phone")
                val filePath = call.argument<String>("filePath")
                val textMessage = call.argument<String>("textMessage")
                if (phone != null && filePath != null) {
                    val shared = sharePdfToWhatsApp(phone, filePath, textMessage)
                    result.success(shared)
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone or File Path was null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Sound Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playSuccessSound") {
                try {
                    val assetManager = applicationContext.assets
                    val fd = assetManager.openFd("flutter_assets/assets/sounds/mixkit-positive-notification-951.wav")
                    val mediaPlayer = android.media.MediaPlayer()
                    mediaPlayer.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                    mediaPlayer.prepare()
                    mediaPlayer.start()
                    fd.close()
                    mediaPlayer.setOnCompletionListener { mp ->
                        mp.release()
                    }
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val r = RingtoneManager.getRingtone(applicationContext, notification)
                        r.play()
                        result.success(true)
                    } catch (e2: Exception) {
                        try {
                            val toneG = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
                            toneG.startTone(ToneGenerator.TONE_PROP_BEEP, 200)
                            result.success(true)
                        } catch (e3: Exception) {
                            result.error("SOUND_ERROR", e3.message, null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sharePdfToWhatsApp(phone: String, filePath: String, textMessage: String?): Boolean {
        val captionText = if (!textMessage.isNullOrBlank()) textMessage else "🧾 DHKIN MOBILES - Invoice"
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            // Create share URI using our custom FileProvider
            val fileUri: Uri = FileProvider.getUriForFile(
                this,
                "com.dhkin.mobiles.fileprovider",
                file
            )

            // Clear plus sign or spaces if any, format to 91XXXXXXXXXX
            var cleanPhone = phone.replace(Regex("[^0-9]"), "")
            if (cleanPhone.length == 10) {
                cleanPhone = "91$cleanPhone"
            }

            // Create Intent to target WhatsApp directly
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, fileUri)
                putExtra("jid", "$cleanPhone@s.whatsapp.net")
                putExtra(Intent.EXTRA_TEXT, captionText)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                `package` = "com.whatsapp"
            }

            // Start activity
            startActivity(sendIntent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback: try Business package com.whatsapp.w4b if normal is not installed
            try {
                val file = File(filePath)
                val fileUri: Uri = FileProvider.getUriForFile(
                    this,
                    "com.dhkin.mobiles.fileprovider",
                    file
                )
                var cleanPhone = phone.replace(Regex("[^0-9]"), "")
                if (cleanPhone.length == 10) {
                    cleanPhone = "91$cleanPhone"
                }

                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "application/pdf"
                    putExtra(Intent.EXTRA_STREAM, fileUri)
                    putExtra("jid", "$cleanPhone@s.whatsapp.net")
                    putExtra(Intent.EXTRA_TEXT, captionText)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    `package` = "com.whatsapp.w4b"
                }
                startActivity(sendIntent)
                true
            } catch (e2: Exception) {
                e2.printStackTrace()
                false
            }
        }
    }
}
