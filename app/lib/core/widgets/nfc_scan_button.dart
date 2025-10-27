import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../nfc/nfc_service.dart';
import '../providers/nfc_provider.dart';

/// A reusable NFC scan button widget that can be used across different screens
class NFCScanButton extends StatefulWidget {
  final String tooltip;
  final Function(String uid)? onUIDScanned;
  final VoidCallback? onScanStarted;
  final VoidCallback? onScanStopped;
  final Function(String error)? onError;
  final IconData? icon;
  final Color? color;
  final bool showDialog;
  final String dialogTitle;
  final String dialogMessage;

  const NFCScanButton({
    super.key,
    this.tooltip = 'Scan NFC Tag',
    this.onUIDScanned,
    this.onScanStarted,
    this.onScanStopped,
    this.onError,
    this.icon,
    this.color,
    this.showDialog = true,
    this.dialogTitle = 'Scanning for NFC Tag',
    this.dialogMessage = 'Hold your device near an NFC tag to scan its UID.',
  });

  @override
  State<NFCScanButton> createState() => _NFCScanButtonState();
}

class _NFCScanButtonState extends State<NFCScanButton> {
  StreamSubscription<NFCEvent>? _nfcSubscription;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeNFC();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeNFC() async {
    try {
      await nfcProvider.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
    } catch (e) {
      widget.onError?.call('Failed to initialize NFC: $e');
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    switch (event.type) {
      case NFCEventType.scanStarted:
        setState(() {
          _isScanning = true;
        });
        widget.onScanStarted?.call();
        break;

      case NFCEventType.scanStopped:
        setState(() {
          _isScanning = false;
        });
        widget.onScanStopped?.call();
        break;

      case NFCEventType.tagDiscovered:
        if (event.uid != null) {
          setState(() {
            _isScanning = false;
          });
          
          // Close scan dialog if open
          if (Navigator.canPop(context) && widget.showDialog) {
            Navigator.pop(context);
          }
          
          widget.onUIDScanned?.call(event.uid!);
        }
        break;

      case NFCEventType.error:
        setState(() {
          _isScanning = false;
        });
        
        // Close scan dialog if open
        if (Navigator.canPop(context) && widget.showDialog) {
          Navigator.pop(context);
        }
        
        widget.onError?.call(event.message ?? 'NFC error occurred');
        break;
    }
  }

  Future<void> _startNFCScan() async {
    try {
      final isSupported = await NFCService.isNFCSupported();
      if (!isSupported) {
        widget.onError?.call('NFC is not supported on this device');
        return;
      }

      final isEnabled = await NFCService.isNFCEnabled();
      if (!isEnabled) {
        widget.onError?.call('NFC is disabled. Please enable NFC in settings.');
        return;
      }

      final success = await NFCService.startScan();
      if (success) {
        if (widget.showDialog) {
          _showNFCScanDialog();
        }
      } else {
        widget.onError?.call('Failed to start NFC scanning');
      }
    } catch (e) {
      widget.onError?.call('Error starting NFC scan: $e');
    }
  }

  void _showNFCScanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(widget.icon ?? Icons.nfc, color: widget.color ?? AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(widget.dialogTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.dialogMessage),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              NFCService.stopScan();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).then((_) {
      if (_isScanning) {
        NFCService.stopScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isScanning ? Icons.stop : (widget.icon ?? Icons.nfc),
        color: _isScanning 
            ? AppTheme.errorColor 
            : (widget.color ?? AppTheme.primaryColor),
      ),
      onPressed: _isScanning ? null : _startNFCScan,
      tooltip: widget.tooltip,
    );
  }
}

/// A floating action button variant of the NFC scan button
class NFCScanFAB extends StatefulWidget {
  final String tooltip;
  final Function(String uid)? onUIDScanned;
  final VoidCallback? onScanStarted;
  final VoidCallback? onScanStopped;
  final Function(String error)? onError;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showDialog;
  final String dialogTitle;
  final String dialogMessage;

  const NFCScanFAB({
    super.key,
    this.tooltip = 'Scan NFC Tag',
    this.onUIDScanned,
    this.onScanStarted,
    this.onScanStopped,
    this.onError,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.showDialog = true,
    this.dialogTitle = 'Scanning for NFC Tag',
    this.dialogMessage = 'Hold your device near an NFC tag to scan its UID.',
  });

  @override
  State<NFCScanFAB> createState() => _NFCScanFABState();
}

class _NFCScanFABState extends State<NFCScanFAB> {
  StreamSubscription<NFCEvent>? _nfcSubscription;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeNFC();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeNFC() async {
    try {
      await nfcProvider.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
    } catch (e) {
      widget.onError?.call('Failed to initialize NFC: $e');
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    switch (event.type) {
      case NFCEventType.scanStarted:
        setState(() {
          _isScanning = true;
        });
        widget.onScanStarted?.call();
        break;

      case NFCEventType.scanStopped:
        setState(() {
          _isScanning = false;
        });
        widget.onScanStopped?.call();
        break;

      case NFCEventType.tagDiscovered:
        if (event.uid != null) {
          setState(() {
            _isScanning = false;
          });
          
          // Close scan dialog if open
          if (Navigator.canPop(context) && widget.showDialog) {
            Navigator.pop(context);
          }
          
          widget.onUIDScanned?.call(event.uid!);
        }
        break;

      case NFCEventType.error:
        setState(() {
          _isScanning = false;
        });
        
        // Close scan dialog if open
        if (Navigator.canPop(context) && widget.showDialog) {
          Navigator.pop(context);
        }
        
        widget.onError?.call(event.message ?? 'NFC error occurred');
        break;
    }
  }

  Future<void> _startNFCScan() async {
    try {
      final isSupported = await NFCService.isNFCSupported();
      if (!isSupported) {
        widget.onError?.call('NFC is not supported on this device');
        return;
      }

      final isEnabled = await NFCService.isNFCEnabled();
      if (!isEnabled) {
        widget.onError?.call('NFC is disabled. Please enable NFC in settings.');
        return;
      }

      final success = await NFCService.startScan();
      if (success) {
        if (widget.showDialog) {
          _showNFCScanDialog();
        }
      } else {
        widget.onError?.call('Failed to start NFC scanning');
      }
    } catch (e) {
      widget.onError?.call('Error starting NFC scan: $e');
    }
  }

  void _showNFCScanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(widget.icon ?? Icons.nfc, color: widget.backgroundColor ?? AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(widget.dialogTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.dialogMessage),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              NFCService.stopScan();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).then((_) {
      if (_isScanning) {
        NFCService.stopScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _isScanning ? null : _startNFCScan,
      backgroundColor: _isScanning 
          ? AppTheme.errorColor 
          : (widget.backgroundColor ?? AppTheme.primaryColor),
      foregroundColor: widget.foregroundColor ?? Colors.white,
      tooltip: widget.tooltip,
      child: Icon(_isScanning ? Icons.stop : (widget.icon ?? Icons.nfc)),
    );
  }
}

/// A text field with integrated NFC scan button
class NFCTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String? Function(String?)? validator;
  final Function(String uid)? onUIDScanned;
  final Function(String error)? onError;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const NFCTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = '',
    this.validator,
    this.onUIDScanned,
    this.onError,
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  State<NFCTextFormField> createState() => _NFCTextFormFieldState();
}

class _NFCTextFormFieldState extends State<NFCTextFormField> {
  void _handleUIDScanned(String uid) {
    widget.controller.text = uid;
    widget.onUIDScanned?.call(uid);
  }

  void _handleError(String error) {
    widget.onError?.call(error);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.credit_card),
        suffixIcon: NFCScanButton(
          onUIDScanned: _handleUIDScanned,
          onError: _handleError,
          tooltip: 'Scan NFC Tag',
        ),
      ),
      validator: widget.validator,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
    );
  }
}