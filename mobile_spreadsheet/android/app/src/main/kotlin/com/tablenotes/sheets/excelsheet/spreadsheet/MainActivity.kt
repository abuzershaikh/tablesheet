package com.tablenotes.sheets.excelsheet.spreadsheet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Environment
import android.util.Log
import java.io.File
import java.io.FileWriter
import kotlin.system.exitProcess

import android.net.Uri
import android.provider.OpenableColumns
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val TEST_CHANNEL = "com.tablenotes.spreadsheet/test_runner"
    private val INTENT_CHANNEL = "com.tablenotes.spreadsheet/intent"
    private var testMethodChannel: MethodChannel? = null
    private var intentMethodChannel: MethodChannel? = null
    private var isTestModeRequested = false
    private var pendingFilePath: String? = null

    private val testReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.i("FormulaTest", "Broadcast received: RUN_FORMULA_TESTS")
            triggerFormulaTests()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkIntentForTestTrigger(intent)
        pendingFilePath = processIntentUri(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkIntentForTestTrigger(intent)
        val filePath = processIntentUri(intent)
        if (filePath != null) {
            pendingFilePath = filePath
            intentMethodChannel?.invokeMethod("onNewFileOpened", filePath)
        }
    }

    private fun checkIntentForTestTrigger(intent: Intent?) {
        val runTestsExtra = intent?.getStringExtra("runTests")
        if (runTestsExtra == "formulas") {
            isTestModeRequested = true
            Log.i("FormulaTest", "Intent Trigger Detected: runTests=formulas")
        }
    }

    private fun processIntentUri(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_EDIT && action != Intent.ACTION_SEND) {
            return null
        }

        var uri: Uri? = intent.data
        if (uri == null && action == Intent.ACTION_SEND) {
            uri = intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
        if (uri == null && intent.clipData != null && intent.clipData!!.itemCount > 0) {
            uri = intent.clipData!!.getItemAt(0).uri
        }

        if (uri == null) return null

        try {
            var fileName: String? = null
            if (uri.scheme == "content") {
                try {
                    val cursor = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (nameIndex != -1) {
                                fileName = it.getString(nameIndex)
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w("SpreadsheetIntent", "Could not query DISPLAY_NAME for uri: $uri", e)
                }
            } else if (uri.scheme == "file") {
                fileName = uri.lastPathSegment
            }

            if (fileName.isNullOrBlank()) {
                fileName = uri.lastPathSegment
            }

            val tempDir = File(context.cacheDir, "imported_sheets")
            if (!tempDir.exists()) tempDir.mkdirs()

            val rawTemp = File(tempDir, "raw_${System.currentTimeMillis()}.tmp")
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(rawTemp).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            if (!rawTemp.exists() || rawTemp.length() == 0L) {
                rawTemp.delete()
                return null
            }

            // Check magic header bytes
            val header = ByteArray(8)
            val bytesRead = try {
                FileInputStream(rawTemp).use { it.read(header) }
            } catch (e: Exception) {
                0
            }

            val isZipOrXlsx = bytesRead >= 4 &&
                    (header[0] == 0x50.toByte() && header[1] == 0x4B.toByte()) &&
                    (header[2] == 0x03.toByte() || header[2] == 0x05.toByte() || header[2] == 0x07.toByte())

            val isOleXls = bytesRead >= 8 &&
                    (header[0] == 0xD0.toByte() && header[1] == 0xCF.toByte()) &&
                    (header[2] == 0x11.toByte() && header[3] == 0xE0.toByte())

            val lowerName = fileName?.lowercase() ?: ""
            val mimeType = try { context.contentResolver.getType(uri) ?: intent.type } catch (e: Exception) { intent.type }

            val extension = when {
                isZipOrXlsx -> if (lowerName.endsWith(".xlsm")) ".xlsm" else ".xlsx"
                isOleXls -> ".xls"
                lowerName.endsWith(".xlsx") -> ".xlsx"
                lowerName.endsWith(".xlsm") -> ".xlsm"
                lowerName.endsWith(".xls") -> ".xls"
                lowerName.endsWith(".tsv") -> ".tsv"
                lowerName.endsWith(".csv") -> ".csv"
                mimeType?.contains("spreadsheetml") == true -> ".xlsx"
                mimeType?.contains("excel") == true -> ".xls"
                mimeType?.contains("csv") == true || mimeType?.contains("comma-separated") == true -> ".csv"
                mimeType?.contains("tab-separated") == true -> ".tsv"
                else -> ".csv"
            }

            val cleanBaseName = if (!fileName.isNullOrBlank()) {
                val nameWithoutExt = if (fileName!!.contains('.')) fileName!!.substringBeforeLast('.') else fileName!!
                val sanitized = nameWithoutExt.replace(Regex("[^a-zA-Z0-9_\\-\\s]"), "_").trim()
                if (sanitized.isEmpty()) "imported_${System.currentTimeMillis()}" else sanitized
            } else {
                "imported_${System.currentTimeMillis()}"
            }

            val finalFile = File(tempDir, "${cleanBaseName}_${System.currentTimeMillis()}$extension")
            if (rawTemp.renameTo(finalFile)) {
                Log.i("SpreadsheetIntent", "Successfully saved imported file to: ${finalFile.absolutePath}")
                return finalFile.absolutePath
            } else {
                FileInputStream(rawTemp).use { input ->
                    FileOutputStream(finalFile).use { output ->
                        input.copyTo(output)
                    }
                }
                rawTemp.delete()
                return finalFile.absolutePath
            }
        } catch (e: Exception) {
            Log.e("SpreadsheetIntent", "Error processing intent URI: $uri", e)
            return null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        testMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TEST_CHANNEL)
        testMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "logTestMessage" -> {
                    val message = call.argument<String>("message") ?: ""
                    Log.i("FormulaTest", message)
                    result.success(true)
                }
                "saveTestResults" -> {
                    val jsonContent = call.argument<String>("jsonContent") ?: "{}"
                    val txtContent = call.argument<String>("txtContent") ?: ""
                    val failedCount = call.argument<Int>("failedCount") ?: 0

                    writeResultsToDisk(jsonContent, txtContent)

                    if (isTestModeRequested && failedCount > 0) {
                        Log.e("FormulaTest", "Tests Failed! Exiting process with code 1 for regression runner.")
                        result.success(false)
                        exitProcess(1)
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        intentMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFilePath" -> {
                    val path = pendingFilePath ?: processIntentUri(intent)
                    pendingFilePath = null
                    intent?.data = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        // Register BroadcastReceiver
        val filter = IntentFilter().apply {
            addAction("com.tablenotes.RUN_FORMULA_TESTS")
            addAction("com.example.RUN_FORMULA_TESTS")
        }
        try {
            registerReceiver(testReceiver, filter, RECEIVER_EXPORTED)
        } catch (e: Exception) {
            try {
                registerReceiver(testReceiver, filter)
            } catch (ex: Exception) {}
        }

        // If intent triggered test, run tests after Flutter engine is ready
        if (isTestModeRequested) {
            flutterEngine.dartExecutor.binaryMessenger.let {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    triggerFormulaTests()
                }, 1000)
            }
        }
    }

    private fun triggerFormulaTests() {
        testMethodChannel?.invokeMethod("startTests", null)
    }

    private fun writeResultsToDisk(jsonContent: String, txtContent: String) {
        val dirsToTry = listOfNotNull(
            File(Environment.getExternalStorageDirectory(), "SpreadsheetTests"),
            context.getExternalFilesDir(null)?.let { File(it, "SpreadsheetTests") },
            File(context.filesDir, "SpreadsheetTests")
        )

        for (dir in dirsToTry) {
            try {
                if (!dir.exists()) dir.mkdirs()
                val jsonFile = File(dir, "results.json")
                val txtFile = File(dir, "results.txt")
                FileWriter(jsonFile).use { it.write(jsonContent) }
                FileWriter(txtFile).use { it.write(txtContent) }
                Log.i("FormulaTest", "Test Reports Saved Successfully to: ${dir.absolutePath}")
            } catch (e: Exception) {
                Log.e("FormulaTest", "Writing to ${dir.absolutePath} failed: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(testReceiver)
        } catch (e: Exception) {}
        super.onDestroy()
    }
}
