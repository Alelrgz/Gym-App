import 'package:flutter/material.dart';

/// Exercise video player — native fallback.
/// Shows a placeholder since HTML5 video is not available on native platforms.
class ExerciseVideoView extends StatelessWidget {
  final String videoUrl;
  const ExerciseVideoView({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Colors.white24, size: 64),
      ),
    );
  }
}
