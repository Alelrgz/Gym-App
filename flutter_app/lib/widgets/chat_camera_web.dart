// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web: opens a full-screen webcam capture dialog using getUserMedia.
/// Photo-only — no barcode scanning, no food analysis.
Future<Uint8List?> capturePhotoForChat(BuildContext context) async {
  return showGeneralDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    pageBuilder: (ctx, anim, secondAnim) => const _WebChatCamera(),
  );
}

class _WebChatCamera extends StatefulWidget {
  const _WebChatCamera();

  @override
  State<_WebChatCamera> createState() => _WebChatCameraState();
}

class _WebChatCameraState extends State<_WebChatCamera> {
  bool _cameraReady = false;
  bool _captured = false;
  bool _facingUser = false;
  String? _error;
  Uint8List? _capturedBytes;

  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  String _viewType = '';

  @override
  void initState() {
    super.initState();
    _viewType = 'chat-camera-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
    _startCamera();
  }

  @override
  void dispose() {
    _stopCamera();
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
        ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _canvasElement = html.CanvasElement()..style.display = 'none';

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
        setState(() => _error = 'Camera non disponibile');
      }
    }
  }

  void _stopCamera() {
    if (_videoElement?.srcObject != null) {
      final tracks =
          (_videoElement!.srcObject as html.MediaStream).getTracks();
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
    canvas.context2D.drawImage(video, 0, 0);

    final blob = await canvas.toBlob('image/jpeg', 0.9);
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

  void _confirm() {
    Navigator.of(context).pop(_capturedBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (!_captured) HtmlElementView(viewType: _viewType),

          // Captured preview
          if (_captured && _capturedBytes != null)
            Image.memory(_capturedBytes!, fit: BoxFit.cover),

          // Error
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Chiudi',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _circleButton(Icons.close_rounded, () => Navigator.of(context).pop(null)),
                const Spacer(),
                if (!_captured && _cameraReady)
                  _circleButton(Icons.flip_camera_ios_rounded, _flipCamera),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: _captured ? _buildReviewControls() : _buildCaptureControls(),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Center(
      child: GestureDetector(
        onTap: _cameraReady ? _takePhoto : null,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: _retake,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text('Riprova',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
        GestureDetector(
          onTap: _confirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text('Invia',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
