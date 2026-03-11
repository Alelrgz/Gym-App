import 'package:flutter/material.dart';

/// Exercise video player — stub for unsupported platforms.
class ExerciseVideoView extends StatelessWidget {
  final String videoUrl;
  const ExerciseVideoView({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
