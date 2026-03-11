// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Exercise video player — web implementation using HTML5 video element.
class ExerciseVideoView extends StatefulWidget {
  final String videoUrl;
  const ExerciseVideoView({super.key, required this.videoUrl});

  @override
  State<ExerciseVideoView> createState() => _ExerciseVideoViewState();
}

class _ExerciseVideoViewState extends State<ExerciseVideoView> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'exercise-video-${widget.videoUrl.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      if (widget.videoUrl.isEmpty) {
        final div = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#1A1A1A'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center';
        div.innerHtml =
            '<span style="font-size:60px;opacity:0.2;">&#127947;</span>';
        return div;
      }

      final video = html.VideoElement()
        ..src = widget.videoUrl
        ..autoplay = true
        ..loop = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.opacity = '0.8'
        ..setAttribute('playsinline', 'true');

      video.play().catchError((_) {});

      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
