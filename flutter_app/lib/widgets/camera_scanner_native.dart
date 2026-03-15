import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/theme.dart';

/// Result from the camera scanner.
class ScanResult {
  final Uint8List? imageBytes; // For photo mode
  final String? barcode; // For barcode mode
  final String mode; // 'photo' or 'barcode'

  ScanResult({this.imageBytes, this.barcode, required this.mode});
}

/// Full-screen camera scanner with live preview.
/// Two modes: Photo (food scanning) and Barcode (product scanning).
class CameraScannerModal extends StatelessWidget {
  const CameraScannerModal({super.key});

  static Future<ScanResult?> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<ScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _LiveScannerPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LiveScannerPage extends StatefulWidget {
  const _LiveScannerPage();

  @override
  State<_LiveScannerPage> createState() => _LiveScannerPageState();
}

class _LiveScannerPageState extends State<_LiveScannerPage> {
  bool _isBarcodeMode = true;
  bool _processing = false;
  String? _lastBarcode;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    // Only accept EAN/UPC barcodes (product codes)
    final barcode = barcodes.first;
    final code = barcode.rawValue;
    if (code == null || code.isEmpty) return;

    // Filter: only accept numeric barcodes of reasonable length (EAN-8, EAN-13, UPC-A)
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) return;
    if (code == _lastBarcode) return;

    setState(() {
      _lastBarcode = code;
    });

    // Show confirmation bottom sheet
    _scannerController.stop();
    _showBarcodeConfirmation(code);
  }

  void _showBarcodeConfirmation(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_rounded,
                color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            const Text('Codice rilevato',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(code,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _lastBarcode = null;
                      _scannerController.start();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Riscansiona'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context)
                          .pop(ScanResult(barcode: code, mode: 'barcode'));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Conferma',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    ).then((_) {
      // If dismissed without action, resume scanning
      if (mounted && !_processing) {
        _lastBarcode = null;
        _scannerController.start();
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      // Stop scanner and use image_picker for a high-quality capture
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          Navigator.of(context).pop(ScanResult(imageBytes: bytes, mode: 'photo'));
          return;
        }
      }

      if (mounted) setState(() => _processing = false);
    } catch (e) {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          Navigator.of(context).pop(ScanResult(imageBytes: bytes, mode: 'photo'));
          return;
        }
      }

      if (mounted) setState(() => _processing = false);
    } catch (e) {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isBarcodeMode)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            )
          else
            // In photo mode, show the scanner as a viewfinder
            MobileScanner(
              controller: _scannerController,
              onDetect: (_) {}, // ignore barcodes in photo mode
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Text(
                    _isBarcodeMode ? 'Scansiona Codice' : 'Scansiona Pasto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  StatefulBuilder(
                    builder: (ctx, setLocal) {
                      final torchOn = _scannerController.value.torchState == TorchState.on;
                      return IconButton(
                        onPressed: () async {
                          await _scannerController.toggleTorch();
                          setLocal(() {});
                        },
                        icon: Icon(
                          torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: torchOn ? AppColors.primary : Colors.white,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Scan overlay
          if (_isBarcodeMode)
            Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    ..._buildCorners(),
                    // Scan line animation
                    const Center(
                      child: Text(
                        'Inquadra il codice a barre',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Photo mode: crosshair
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'Inquadra il pasto',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 20,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modeButton(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Barcode',
                          active: _isBarcodeMode,
                          onTap: () {
                            setState(() {
                              _isBarcodeMode = true;
                              _lastBarcode = null;
                            });
                          },
                        ),
                        _modeButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Foto',
                          active: !_isBarcodeMode,
                          onTap: () {
                            setState(() => _isBarcodeMode = false);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  if (!_isBarcodeMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery button
                        _circleButton(
                          icon: Icons.photo_library_rounded,
                          size: 52,
                          onTap: _pickFromGallery,
                        ),
                        // Capture button
                        GestureDetector(
                          onTap: _processing ? null : _capturePhoto,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 4),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _processing
                                    ? Colors.grey
                                    : AppColors.primary,
                              ),
                              child: _processing
                                  ? const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                        // Flip camera
                        _circleButton(
                          icon: Icons.flip_camera_android_rounded,
                          size: 52,
                          onTap: () => _scannerController.switchCamera(),
                        ),
                      ],
                    )
                  else
                    // Barcode mode — just show gallery option for barcode images
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleButton(
                          icon: Icons.flip_camera_android_rounded,
                          size: 52,
                          onTap: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Processing overlay
          if (_processing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 3.0;
    const color = AppColors.primary;

    Widget corner(Alignment align) {
      final isTop = align.y < 0;
      final isLeft = align.x < 0;
      return Positioned(
        top: isTop ? 0 : null,
        bottom: !isTop ? 0 : null,
        left: isLeft ? 0 : null,
        right: !isLeft ? 0 : null,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CornerPainter(
              isTop: isTop,
              isLeft: isLeft,
              color: color,
              thickness: thickness,
            ),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;
  final double thickness;

  _CornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
