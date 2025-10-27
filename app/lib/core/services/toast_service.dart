import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/custom_toast.dart';

enum ToastType {
  success,
  error,
  warning,
  info,
}

class ToastMessage {
  final String message;
  final ToastType type;
  final DateTime timestamp;
  final String id;

  ToastMessage({
    required this.message,
    required this.type,
    required this.timestamp,
    required this.id,
  });
}

class ToastService {
  static final ToastService _instance = ToastService._internal();
  factory ToastService() => _instance;
  ToastService._internal();

  final List<ToastMessage> _messageQueue = [];
  Timer? _queueTimer;
  bool _isShowingToast = false;
  static BuildContext? _context;

  // Configuration
  static const Duration _toastDuration = Duration(seconds: 5);
  static const Duration _errorToastDuration = Duration(seconds: 5);
  static const Duration _queueDelay = Duration(milliseconds: 100);

  // Set context for toast display
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// Show a success toast
  static void showSuccess(String message) {
    _instance._addToQueue(message, ToastType.success);
  }

  /// Show an error toast
  static void showError(String message) {
    _instance._addToQueue(message, ToastType.error);
  }

  /// Show a warning toast
  static void showWarning(String message) {
    _instance._addToQueue(message, ToastType.warning);
  }

  /// Show an info toast
  static void showInfo(String message) {
    _instance._addToQueue(message, ToastType.info);
  }

  /// Clear all pending toasts
  static void clearAll() {
    _instance._clearQueue();
  }

  /// Cancel current toast and clear queue
  static void cancelCurrent() {
    _instance._cancelCurrentToast();
  }

  void _addToQueue(String message, ToastType type) {
    // Always dismiss current toast and clear queue for any new message
    _cancelCurrentToast();
    _clearQueue();
    
    final toastMessage = ToastMessage(
      message: message,
      type: type,
      timestamp: DateTime.now(),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    _messageQueue.add(toastMessage);
    _processQueue();
  }

  void _processQueue() {
    if (_isShowingToast || _messageQueue.isEmpty) return;

    _queueTimer?.cancel();
    _queueTimer = Timer(_queueDelay, () {
      _showNextToast();
    });
  }

  void _showNextToast() {
    if (_messageQueue.isEmpty || _isShowingToast || _context == null) return;

    final toastMessage = _messageQueue.removeAt(0);
    _isShowingToast = true;

    final duration = toastMessage.type == ToastType.error 
        ? _errorToastDuration 
        : _toastDuration;

    // Convert ToastType to CustomToastType
    CustomToastType customType;
    switch (toastMessage.type) {
      case ToastType.success:
        customType = CustomToastType.success;
        break;
      case ToastType.error:
        customType = CustomToastType.error;
        break;
      case ToastType.warning:
        customType = CustomToastType.warning;
        break;
      case ToastType.info:
        customType = CustomToastType.info;
        break;
    }

    // Show toast in top right corner with overlay
    CustomToast.show(
      _context!,
      message: toastMessage.message,
      type: customType,
      duration: duration,
      showCloseButton: true,
    );

    // Schedule next toast with a small delay to prevent rapid succession
    Timer(duration + const Duration(milliseconds: 200), () {
      _isShowingToast = false;
      _processQueue();
    });
  }

  void _clearQueue() {
    _messageQueue.clear();
    _queueTimer?.cancel();
  }

  void _cancelCurrentToast() {
    if (_isShowingToast) {
      CustomToast.dismiss();
      _isShowingToast = false;
    }
  }

  /// Dispose resources
  static void dispose() {
    _instance._queueTimer?.cancel();
    _instance._clearQueue();
    CustomToast.dismiss();
  }
}

/// Extension for easy context-based toast usage
extension ToastExtension on BuildContext {
  void showSuccessToast(String message) {
    ToastService.showSuccess(message);
  }

  void showErrorToast(String message) {
    ToastService.showError(message);
  }

  void showWarningToast(String message) {
    ToastService.showWarning(message);
  }

  void showInfoToast(String message) {
    ToastService.showInfo(message);
  }
}