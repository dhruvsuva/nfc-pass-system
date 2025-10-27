package com.nfcpass.manager

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity(), NfcAdapter.ReaderCallback {
    private val CHANNEL = "com.nfcpass.manager/nfc"
    private val EVENT_CHANNEL = "com.nfcpass.manager/nfc_events"
    private val TAG = "NFCPassApp"
    
    private var nfcAdapter: NfcAdapter? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isScanning = false
    
    // NFC Reader flags - exclude NDEF to avoid system popup
    private val readerFlags = NfcAdapter.FLAG_READER_NFC_A or
                             NfcAdapter.FLAG_READER_NFC_B or
                             NfcAdapter.FLAG_READER_NFC_F or
                             NfcAdapter.FLAG_READER_NFC_V or
                             NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                             NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize NFC adapter
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        // Setup Method Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNFCSupported" -> {
                    result.success(isNFCSupported())
                }
                "isNFCEnabled" -> {
                    result.success(isNFCEnabled())
                }
                "startScan" -> {
                    if (startNFCScan()) {
                        result.success(true)
                    } else {
                        result.error("NFC_ERROR", "Failed to start NFC scan", null)
                    }
                }
                "stopScan" -> {
                    stopNFCScan()
                    result.success(true)
                }
                "writeTag" -> {
                    val uid = call.argument<String>("uid")
                    val payload = call.argument<String>("payload")
                    if (uid != null && payload != null) {
                        // TODO: Implement NFC writing if needed
                        result.success(false) // Not implemented yet
                    } else {
                        result.error("INVALID_ARGS", "UID and payload required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Setup Event Channel for NFC events
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "Event channel listener attached")
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "Event channel listener cancelled")
            }
        })
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created")
        
        // Handle NFC intent if app was launched by NFC
        handleNFCIntent(intent)
    }
    
    override fun onResume() {
        super.onResume()
        // Enable exclusive NFC reader mode to block default scanner
        enableExclusiveNFCMode()
        Log.d(TAG, "Activity resumed - exclusive NFC mode enabled")
    }
    
    override fun onPause() {
        super.onPause()
        // Disable exclusive NFC mode and stop scanning when app goes to background
        disableExclusiveNFCMode()
        if (isScanning) {
            stopNFCScan()
        }
        Log.d(TAG, "Activity paused - exclusive NFC mode disabled")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clean up NFC scanning
        if (isScanning) {
            stopNFCScan()
        }
        Log.d(TAG, "Activity destroyed")
    }
    
    private fun isNFCSupported(): Boolean {
        return nfcAdapter != null
    }
    
    private fun isNFCEnabled(): Boolean {
        return nfcAdapter?.isEnabled == true
    }
    
    private fun startNFCScan(): Boolean {
        if (!isNFCSupported()) {
            Log.e(TAG, "NFC not supported on this device")
            return false
        }
        
        if (!isNFCEnabled()) {
            Log.e(TAG, "NFC is disabled")
            return false
        }
        
        if (isScanning) {
            Log.w(TAG, "NFC scan already in progress")
            return true
        }
        
        // Since exclusive mode is already enabled in onResume, just mark as scanning
        isScanning = true
        Log.d(TAG, "NFC scanning started (exclusive mode already active)")
        
        // Notify Flutter that scanning started
        eventSink?.success(mapOf(
            "type" to "scan_started",
            "message" to "NFC scanning started"
        ))
        
        return true
    }
    
    private fun stopNFCScan() {
        if (!isScanning) {
            return
        }
        
        // Only change scanning flag, keep exclusive mode active while app is in foreground
        isScanning = false
        Log.d(TAG, "NFC scanning stopped (exclusive mode remains active)")
        
        // Notify Flutter that scanning stopped
        eventSink?.success(mapOf(
            "type" to "scan_stopped",
            "message" to "NFC scanning stopped"
        ))
    }
    
    private fun enableExclusiveNFCMode() {
        if (!isNFCSupported() || !isNFCEnabled()) {
            Log.w(TAG, "NFC not supported or not enabled")
            return
        }
        
        try {
            // Enable reader mode with exclusive access to block default NFC scanner
            nfcAdapter?.enableReaderMode(
                this as android.app.Activity,
                this,
                readerFlags,
                null
            )
            Log.d(TAG, "Exclusive NFC mode enabled - default scanner blocked")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable exclusive NFC mode: ${e.message}")
        }
    }
    
    private fun disableExclusiveNFCMode() {
        try {
            nfcAdapter?.disableReaderMode(this as android.app.Activity)
            Log.d(TAG, "Exclusive NFC mode disabled - default scanner restored")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disable exclusive NFC mode: ${e.message}")
        }
    }
    
    // NfcAdapter.ReaderCallback implementation
    override fun onTagDiscovered(tag: Tag?) {
        if (tag == null) {
            Log.w(TAG, "Null tag discovered")
            return
        }
        
        try {
            val uid = bytesToHex(tag.id)
            Log.d(TAG, "NFC Tag discovered - UID: $uid")
            
            // Get additional tag information
            val techList = tag.techList
            val tagInfo = mapOf(
                "uid" to uid,
                "techList" to techList.toList(),
                "timestamp" to System.currentTimeMillis()
            )
            
            // Send tag data to Flutter via event channel
            (this as android.app.Activity).runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to "tag_discovered",
                    "data" to tagInfo
                ))
            }
            
            Log.d(TAG, "Tag data sent to Flutter: $tagInfo")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing NFC tag: ${e.message}")
            
            (this as android.app.Activity).runOnUiThread {
                eventSink?.error(
                    "TAG_ERROR",
                    "Failed to process NFC tag: ${e.message}",
                    null
                )
            }
        }
    }
    
    private fun bytesToHex(bytes: ByteArray): String {
        val hexChars = "0123456789ABCDEF"
        val result = StringBuilder(bytes.size * 2)
        
        for (byte in bytes) {
            val i = byte.toInt()
            result.append(hexChars[i shr 4 and 0x0f])
            result.append(hexChars[i and 0x0f])
        }
        
        return result.toString()
    }
    
    // Handle NFC intent (fallback, should not be used with reader mode)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNFCIntent(intent)
    }
    
    private fun handleNFCIntent(intent: Intent) {
        if (isScanning) {
            Log.d(TAG, "Reader mode is active, ignoring NFC intent")
            return
        }
        
        if (NfcAdapter.ACTION_TAG_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TECH_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action) {
            
            Log.i(TAG, "NFC intent received: ${intent.action}")
            
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
            if (tag != null) {
                Log.d(TAG, "Processing NFC tag from intent")
                onTagDiscovered(tag)
            }
        }
    }
}