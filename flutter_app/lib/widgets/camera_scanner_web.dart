// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Result from the camera scanner.
class ScanResult {
  final Uint8List? imageBytes;  // For photo mode
  final String? barcode;        // For barcode mode
  final String mode;            // 'photo' or 'barcode'

  ScanResult({this.imageBytes, this.barcode, required this.mode});
}

/// Full-screen camera scanner with Photo and Barcode modes.
class CameraScannerModal extends StatefulWidget {
  const CameraScannerModal({super.key});

  static Future<ScanResult?> show(BuildContext context) {
    return showGeneralDialog<ScanResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      pageBuilder: (ctx, anim, secondAnim) => const CameraScannerModal(),
    );
  }

  @override
  State<CameraScannerModal> createState() => _CameraScannerModalState();
}

class _CameraScannerModalState extends State<CameraScannerModal> {
  String _mode = 'photo'; // 'photo' or 'barcode'
  bool _cameraReady = false;
  bool _captured = false;
  bool _facingUser = false;
  String? _error;
  Uint8List? _capturedBytes;

  // HTML elements
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  String _viewType = '';
  bool _quaggaRunning = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'camera-scanner-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
    _startCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    _stopBarcodePolling();
    super.dispose();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative'
        ..style.backgroundColor = '#000';

      _videoElement = html.VideoElement()
        ..id = 'gym-scanner-video'
        ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _canvasElement = html.CanvasElement()
        ..style.display = 'none'
        ..id = 'gym-barcode-canvas';

      // Store canvas globally so injected JS can access it
      html.window.document.documentElement!.dataset['gymCanvas'] = 'gym-barcode-canvas';

      container.children.addAll([_videoElement!, _canvasElement!]);
      return container;
    });
  }

  Future<void> _startCamera() async {
    try {
      final constraints = {
        'video': {
          'facingMode': _facingUser ? 'user' : 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      };

      final stream = await html.window.navigator.mediaDevices!
          .getUserMedia(constraints);

      if (_videoElement != null) {
        _videoElement!.srcObject = stream;
        await _videoElement!.play();
        if (mounted) {
          setState(() {
            _cameraReady = true;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Camera non disponibile: $e';
        });
      }
    }
  }

  void _stopCamera() {
    if (_videoElement?.srcObject != null) {
      final tracks = (_videoElement!.srcObject as html.MediaStream).getTracks();
      for (final track in tracks) {
        track.stop();
      }
      _videoElement!.srcObject = null;
    }
  }

  void _flipCamera() {
    _stopCamera();
    setState(() {
      _facingUser = !_facingUser;
      _cameraReady = false;
    });
    _startCamera();
  }

  Future<void> _takePhoto() async {
    if (_videoElement == null || _canvasElement == null) return;

    final video = _videoElement!;
    final canvas = _canvasElement!;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);

    // Convert to JPEG blob
    final blob = await canvas.toBlob('image/jpeg', 0.9);
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else if (result is String) {
        // Data URL
        completer.complete(Uint8List(0));
      } else {
        completer.complete(Uint8List(0));
      }
    });
    reader.readAsArrayBuffer(blob);

    final bytes = await completer.future;
    if (bytes.isNotEmpty && mounted) {
      setState(() {
        _capturedBytes = bytes;
        _captured = true;
      });
    }
  }

  void _retake() {
    setState(() {
      _captured = false;
      _capturedBytes = null;
    });
  }

  void _confirmPhoto() {
    Navigator.of(context).pop(ScanResult(
      imageBytes: _capturedBytes,
      mode: 'photo',
    ));
  }

  void _switchMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
    });

    if (mode == 'barcode') {
      _startBarcodePolling();
    } else {
      _stopBarcodePolling();
    }
  }

  /// Barcode scanning state
  StreamSubscription? _barcodeSubscription;
  bool _barcodeFound = false;

  void _startBarcodePolling() {
    if (_quaggaRunning) return;
    _barcodeFound = false;

    // Listen for barcode result via CustomEvent from JS
    _barcodeSubscription = html.window.on['gymBarcodeDetected'].listen((event) {
      if (_barcodeFound) return;
      final customEvent = event as html.CustomEvent;
      final code = customEvent.detail?.toString();
      if (code != null && code.isNotEmpty && mounted && _quaggaRunning) {
        _barcodeFound = true;
        _stopBarcodePolling();
        _stopCamera();
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            Navigator.of(context).pop(ScanResult(
              barcode: code,
              mode: 'barcode',
            ));
          }
        });
      }
    });

    // Use Quagga in LiveStream mode — processes the video stream directly
    // Much more reliable than decodeSingle with data URLs
    final setupScript = html.ScriptElement()
      ..text = '''
(function() {
  // Stop any previous Quagga instance
  try { Quagga.stop(); } catch(e) {}

  if (typeof Quagga === 'undefined') {
    console.log('[Scanner] Quagga not loaded!');
    return;
  }

  var video = document.getElementById('gym-scanner-video');
  if (!video || !video.srcObject) {
    console.log('[Scanner] Video element not ready');
    return;
  }

  // Create a container div for Quagga's viewport
  var container = document.getElementById('gym-quagga-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'gym-quagga-container';
    container.style.cssText = 'position:absolute;top:0;left:0;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;';
    document.body.appendChild(container);
  }

  Quagga.init({
    inputStream: {
      name: 'Live',
      type: 'LiveStream',
      target: container,
      constraints: {
        deviceId: video.srcObject.getVideoTracks()[0].getSettings().deviceId
      }
    },
    decoder: {
      readers: ['ean_reader', 'ean_8_reader', 'upc_reader', 'upc_e_reader', 'code_128_reader']
    },
    locate: true,
    frequency: 5
  }, function(err) {
    if (err) {
      console.log('[Scanner] Quagga init error:', err);
      return;
    }
    console.log('[Scanner] Quagga LiveStream started');
    Quagga.start();
  });

  // Validate EAN/UPC checksum
  function isValidBarcode(code) {
    if (!code || !/^[0-9]+\$/.test(code)) return false;
    var len = code.length;
    if (len !== 8 && len !== 12 && len !== 13 && len !== 14) return false;
    var sum = 0;
    for (var i = 0; i < len - 1; i++) {
      var digit = parseInt(code[i]);
      if (len === 13 || len === 8) {
        sum += (i % 2 === 0) ? digit : digit * 3;
      } else {
        sum += (i % 2 === 0) ? digit * 3 : digit;
      }
    }
    var check = (10 - (sum % 10)) % 10;
    return check === parseInt(code[len - 1]);
  }

  // Require 2 consistent reads to avoid false positives
  var lastCode = null;
  var readCount = 0;

  Quagga.onDetected(function(result) {
    if (result && result.codeResult && result.codeResult.code) {
      var code = result.codeResult.code;
      if (!isValidBarcode(code)) {
        console.log('[Scanner] Invalid checksum: ' + code);
        return;
      }
      if (code === lastCode) {
        readCount++;
      } else {
        lastCode = code;
        readCount = 1;
      }
      if (readCount >= 2) {
        console.log('[Scanner] Confirmed: ' + code + ' (' + readCount + ' reads)');
        Quagga.stop();
        window.dispatchEvent(new CustomEvent('gymBarcodeDetected', { detail: code }));
      } else {
        console.log('[Scanner] Read 1/2: ' + code);
      }
    }
  });
})();
''';
    html.document.head!.append(setupScript);
    _quaggaRunning = true;
  }

  void _stopBarcodePolling() {
    _barcodeSubscription?.cancel();
    _barcodeSubscription = null;
    _quaggaRunning = false;
    // Stop Quagga live stream
    final script = html.ScriptElement()
      ..text = '''
(function() {
  try { Quagga.offDetected(); Quagga.stop(); } catch(e) {}
  var c = document.getElementById('gym-quagga-container');
  if (c) c.remove();
})();
''';
    html.document.head!.append(script);
  }

  void _openGallery() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;

    final file = input.files!.first;
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.complete(Uint8List(0));
      }
    });
    reader.readAsArrayBuffer(file);

    final bytes = await completer.future;
    if (bytes.isNotEmpty && mounted) {
      Navigator.of(context).pop(ScanResult(
        imageBytes: bytes,
        mode: 'photo',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (HTML element)
          if (!_captured)
            HtmlElementView(viewType: _viewType),

          // Captured preview overlay
          if (_captured && _capturedBytes != null)
            Image.memory(_capturedBytes!, fit: BoxFit.cover),

          // Corner markers overlay (photo mode)
          if (_mode == 'photo' && !_captured)
            _buildCornerMarkers(),

          // Barcode scan line overlay
          if (_mode == 'barcode' && !_captured)
            _buildBarcodeLine(),

          // Error message
          if (_error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _openGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Text('Apri Galleria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const Spacer(),
                // Title
                const Text('Scansiona Pasto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                // Flip camera button
                if (!_captured)
                  GestureDetector(
                    onTap: _flipCamera,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                    ),
                  ),
              ],
            ),
          ),

          // Mode toggle tabs
          if (!_captured)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _modeTab('Foto', 'photo'),
                      _modeTab('Barcode', 'barcode'),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0, right: 0,
            child: _captured ? _buildReviewControls() : _buildCaptureControls(),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String label, String mode) {
    final isActive = _mode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery button
        GestureDetector(
          onTap: _openGallery,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
          ),
        ),
        // Capture button (photo mode only)
        if (_mode == 'photo')
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  width: 58, height: 58,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          )
        else
          // Barcode mode: info text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Inquadra il codice a barre',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        // Spacer for symmetry
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildReviewControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retake
        GestureDetector(
          onTap: _retake,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text('Riprova', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
        // Confirm / Analyze
        GestureDetector(
          onTap: _confirmPhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryHover]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Text('Analizza', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerMarkers() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260, height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: CustomPaint(painter: _CornerPainter()),
        ),
      ),
    );
  }

  Widget _buildBarcodeLine() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280, height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: Container(
              width: 260, height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 30.0;
    const r = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, len),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..quadraticBezierTo(0, size.height, r, size.height)
        ..lineTo(len, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..quadraticBezierTo(size.width, size.height, size.width, size.height - r)
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
