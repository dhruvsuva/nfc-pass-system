import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../config/app_config.dart';

class NFCService {
  static const MethodChannel _methodChannel = MethodChannel(AppConfig.nfcChannelName);
  static const EventChannel _eventChannel = EventChannel(AppConfig.nfcEventChannelName);
  
  static StreamSubscription<dynamic>? _eventSubscription;
  static final StreamController<NFCEvent> _nfcEventController = StreamController<NFCEvent>.broadcast();
  // Audio player would be initialized here when dependency is available
  static AudioPlayer? _audioPlayer;
  
  static bool _isScanning = false;
  static bool _isInitialized = false;
  
  // Public stream for NFC events
  static Stream<NFCEvent> get nfcEventStream => _nfcEventController.stream;
  
  static bool get isScanning => _isScanning;
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔧 Initializing NFCService...');
      
      // Initialize audio player for feedback sounds
      _audioPlayer = AudioPlayer();
      
      // Set up event channel listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleNFCEvent,
        onError: _handleNFCError,
      );
      
      _isInitialized = true;
      print('✅ NFCService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize NFCService: $e');
      rethrow;
    }
  }
  
  static Future<bool> isNFCSupported() async {
    try {
      final bool supported = await _methodChannel.invokeMethod('isNFCSupported');
      return supported;
    } catch (e) {
      print('Error checking NFC support: $e');
      return false;
    }
  }
  
  static Future<bool> isNFCEnabled() async {
    try {
      final bool enabled = await _methodChannel.invokeMethod('isNFCEnabled');
      return enabled;
    } catch (e) {
      print('Error checking NFC enabled: $e');
      return false;
    }
  }
  
  static Future<bool> startScan() async {
    if (_isScanning) {
      print('NFC scan already in progress');
      return true;
    }
    
    try {
      final bool success = await _methodChannel.invokeMethod('startScan');
      if (success) {
        _isScanning = true;
        _nfcEventController.add(NFCEvent(
          type: NFCEventType.scanStarted,
          message: 'NFC scanning started',
        ));
      }
      return success;
    } catch (e) {
      print('Error starting NFC scan: $e');
      _nfcEventController.add(NFCEvent(
        type: NFCEventType.error,
        message: 'Failed to start NFC scan: $e',
      ));
      return false;
    }
  }
  
  static Future<void> stopScan() async {
    if (!_isScanning) {
      return;
    }
    
    try {
      await _methodChannel.invokeMethod('stopScan');
      _isScanning = false;
      _nfcEventController.add(NFCEvent(
        type: NFCEventType.scanStopped,
        message: 'NFC scanning stopped',
      ));
    } catch (e) {
      print('Error stopping NFC scan: $e');
    }
  }
  
  static Future<bool> writeTag(String uid, String payload) async {
    try {
      final bool success = await _methodChannel.invokeMethod('writeTag', {
        'uid': uid,
        'payload': payload,
      });
      return success;
    } catch (e) {
      print('Error writing NFC tag: $e');
      return false;
    }
  }
  
  static void _handleNFCEvent(dynamic event) {
    print('🎯 NFCService._handleNFCEvent received: $event');
    try {
      // Convert the event to Map<String, dynamic>
      Map<String, dynamic> eventMap;
      if (event is Map<String, dynamic>) {
        eventMap = event;
      } else if (event is Map) {
        eventMap = Map<String, dynamic>.from(event);
      } else {
        print('❌ Event is not a Map: ${event.runtimeType}');
        return;
      }
      
      final String type = eventMap['type'] as String;
      print('📋 Event type: $type');
        
        switch (type) {
          case 'scan_started':
            _isScanning = true;
            print('✅ Scan started event');
            _nfcEventController.add(NFCEvent(
              type: NFCEventType.scanStarted,
              message: eventMap['message'] as String?,
            ));
            break;
            
          case 'scan_stopped':
            _isScanning = false;
            print('⏹️ Scan stopped event');
            _nfcEventController.add(NFCEvent(
              type: NFCEventType.scanStopped,
              message: eventMap['message'] as String?,
            ));
            break;
            
          case 'tag_discovered':
            print('🏷️ Tag discovered event received');
            
            // Convert tagData to Map<String, dynamic>
            Map<String, dynamic> tagData;
            final dynamic rawData = eventMap['data'];
            if (rawData is Map<String, dynamic>) {
              tagData = rawData;
            } else if (rawData is Map) {
              tagData = Map<String, dynamic>.from(rawData);
            } else {
              print('❌ Tag data is not a Map: ${rawData.runtimeType}');
              return;
            }
            
            final String uid = tagData['uid'] as String;
            print('🆔 Extracted UID: $uid');
            
            // Provide haptic and audio feedback
            _provideFeedback(true);
            
            final nfcEvent = NFCEvent(
              type: NFCEventType.tagDiscovered,
              uid: uid,
              tagData: tagData,
              message: 'NFC tag discovered: $uid',
            );
            
            print('📤 Adding event to controller: $nfcEvent');
            _nfcEventController.add(nfcEvent);
            print('✅ Event added to stream');
            break;
            
          default:
            print('❓ Unknown NFC event type: $type');
        }
    } catch (e) {
      print('💥 Error handling NFC event: $e');
      _nfcEventController.add(NFCEvent(
        type: NFCEventType.error,
        message: 'Error processing NFC event: $e',
      ));
    }
  }
  
  static void _handleNFCError(dynamic error) {
    print('NFC Event Channel Error: $error');
    _provideFeedback(false);
    
    _nfcEventController.add(NFCEvent(
      type: NFCEventType.error,
      message: 'NFC error: $error',
    ));
  }
  
  static Future<void> _provideFeedback(bool success) async {
    try {
      // Immediate haptic feedback
      if (success) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.heavyImpact();
      }
      
      // Audio feedback using system sounds
      if (_audioPlayer != null) {
        try {
          if (success) {
            // Play a short success beep sound
            await SystemSound.play(SystemSoundType.click);
          } else {
            // Play error sound
            await SystemSound.play(SystemSoundType.alert);
          }
        } catch (audioError) {
          print('Audio feedback error: $audioError');
          // Fallback to system sound
          await SystemSound.play(success ? SystemSoundType.click : SystemSoundType.alert);
        }
      }
      
      print(success ? '✅ Success feedback provided' : '❌ Error feedback provided');
      
    } catch (e) {
      print('Error providing feedback: $e');
    }
  }
  
  static void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _nfcEventController.close();
    
    // Dispose audio player
    _audioPlayer?.dispose();
    _audioPlayer = null;
    
    _isInitialized = false;
    _isScanning = false;
  }
}

enum NFCEventType {
  scanStarted,
  scanStopped,
  tagDiscovered,
  error,
}

class NFCEvent {
  final NFCEventType type;
  final String? uid;
  final Map<String, dynamic>? tagData;
  final String? message;
  final DateTime timestamp;
  
  NFCEvent({
    required this.type,
    this.uid,
    this.tagData,
    this.message,
  }) : timestamp = DateTime.now();
  
  @override
  String toString() {
    return 'NFCEvent(type: $type, uid: $uid, message: $message, timestamp: $timestamp)';
  }
}

// NFC Tag Information
class NFCTagInfo {
  final String uid;
  final List<String> techList;
  final DateTime timestamp;
  
  const NFCTagInfo({
    required this.uid,
    required this.techList,
    required this.timestamp,
  });
  
  factory NFCTagInfo.fromMap(Map<String, dynamic> map) {
    return NFCTagInfo(
      uid: map['uid'] as String,
      techList: List<String>.from(map['techList'] as List),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'techList': techList,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  @override
  String toString() {
    return 'NFCTagInfo(uid: $uid, techList: $techList, timestamp: $timestamp)';
  }
}