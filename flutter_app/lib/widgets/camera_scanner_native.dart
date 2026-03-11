import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';

/// Result from the camera scanner.
class ScanResult {
  final Uint8List? imageBytes; // For photo mode
  final String? barcode; // For barcode mode
  final String mode; // 'photo' or 'barcode'

  ScanResult({this.imageBytes, this.barcode, required this.mode});
}

/// Native camera scanner — uses image_picker for photos.
/// Barcode scanning on native would require a dedicated package (e.g. mobile_scanner).
class CameraScannerModal extends StatelessWidget {
  const CameraScannerModal({super.key});

  static Future<ScanResult?> show(BuildContext context) async {
    final picker = ImagePicker();

    // Show a bottom sheet to choose photo or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scansiona Pasto',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('Scatta Foto',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Galleria',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;

    return ScanResult(imageBytes: bytes, mode: 'photo');
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
