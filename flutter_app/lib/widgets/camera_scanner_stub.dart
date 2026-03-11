import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Result from the camera scanner.
class ScanResult {
  final Uint8List? imageBytes; // For photo mode
  final String? barcode; // For barcode mode
  final String mode; // 'photo' or 'barcode'

  ScanResult({this.imageBytes, this.barcode, required this.mode});
}

/// Full-screen camera scanner with Photo and Barcode modes.
/// Stub — the actual implementation is selected via conditional import.
class CameraScannerModal extends StatelessWidget {
  const CameraScannerModal({super.key});

  static Future<ScanResult?> show(BuildContext context) {
    throw UnsupportedError(
        'CameraScannerModal is not implemented for this platform');
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
