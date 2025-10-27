import 'dart:async';
import 'package:flutter/foundation.dart';

import '../nfc/nfc_service.dart';

class NFCProvider extends ChangeNotifier {
  static final NFCProvider _instance = NFCProvider._internal();
  factory NFCProvider() => _instance;
  NFCProvider._internal();
  
  StreamSubscription<NFCEvent>? _nfcSubscription;
  
  // NFC State
  bool _isScanning = false;
  bool _isInitialized = false;
  String? _lastScannedUID;
  String? _lastError;
  NFCEvent? _lastEvent;
  
  // Getters
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  String? get lastScannedUID => _lastScannedUID;
  String? get lastError => _lastError;
  NFCEvent? get lastEvent => _lastEvent;
  
  // Initialize NFC service and start listening to events
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await NFCService.initialize();
      
      // Listen to NFC events
      _nfcSubscription = NFCService.nfcEventStream.listen(
        _handleNFCEvent,
        onError: _handleNFCError,
      );
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('NFCProvider initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize NFC: $e';
      debugPrint('NFCProvider initialization failed: $e');
      notifyListeners();
      rethrow;
    }
  }
  
  // Handle NFC events
  void _handleNFCEvent(NFCEvent event) {
    _lastEvent = event;
    _lastError = null; // Clear previous errors
    
    switch (event.type) {
      case NFCEventType.scanStarted:
        _isScanning = true;
        break;
        
      case NFCEventType.scanStopped:
        _isScanning = false;
        break;
        
      case NFCEventType.tagDiscovered:
        _isScanning = false;
        _lastScannedUID = event.uid;
        break;
        
      case NFCEventType.error:
        _isScanning = false;
        _lastError = event.message;
        break;
    }
    
    notifyListeners();
  }
  
  // Handle NFC errors
  void _handleNFCError(dynamic error) {
    _isScanning = false;
    _lastError = 'NFC error: $error';
    notifyListeners();
  }
  
  // Start NFC scanning
  Future<bool> startScan() async {
    try {
      // Check NFC support and availability
      final isSupported = await NFCService.isNFCSupported();
      if (!isSupported) {
        _lastError = 'NFC is not supported on this device';
        notifyListeners();
        return false;
      }
      
      final isEnabled = await NFCService.isNFCEnabled();
      if (!isEnabled) {
        _lastError = 'NFC is disabled. Please enable NFC in settings.';
        notifyListeners();
        return false;
      }
      
      // Clear previous UID and error
      _lastScannedUID = null;
      _lastError = null;
      
      final success = await NFCService.startScan();
      if (success) {
        _isScanning = true;
      } else {
        _lastError = 'Failed to start NFC scanning';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _isScanning = false;
      _lastError = 'Error starting NFC scan: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Stop NFC scanning
  Future<void> stopScan() async {
    try {
      await NFCService.stopScan();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _lastError = 'Error stopping NFC scan: $e';
      notifyListeners();
    }
  }
  
  // Clear the last scanned UID
  void clearLastScannedUID() {
    _lastScannedUID = null;
    notifyListeners();
  }
  
  // Clear the last error
  void clearLastError() {
    _lastError = null;
    notifyListeners();
  }
  
  // Check if NFC is supported
  Future<bool> isNFCSupported() async {
    try {
      return await NFCService.isNFCSupported();
    } catch (e) {
      return false;
    }
  }
  
  // Check if NFC is enabled
  Future<bool> isNFCEnabled() async {
    try {
      return await NFCService.isNFCEnabled();
    } catch (e) {
      debugPrint('Error checking NFC enabled: $e');
      return false;
    }
  }
  
  // Write to NFC tag
  Future<bool> writeTag(String uid, String payload) async {
    try {
      return await NFCService.writeTag(uid, payload);
    } catch (e) {
      _lastError = 'Error writing NFC tag: $e';
      debugPrint('Error writing NFC tag: $e');
      notifyListeners();
      return false;
    }
  }
  
  @override
  void dispose() {
    _nfcSubscription?.cancel();
    _nfcSubscription = null;
    NFCService.dispose();
    super.dispose();
  }
}

// Global instance for easy access
final nfcProvider = NFCProvider();