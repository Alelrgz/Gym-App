import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Native (iOS/Android/desktop): uses image_picker to open the device camera.
Future<Uint8List?> capturePhotoForChat(BuildContext context) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1200,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}
