import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Exercise video player — native implementation using media_kit.
/// Auto-plays, loops, and mutes the video (background demo).
class ExerciseVideoView extends StatefulWidget {
  final String videoUrl;
  const ExerciseVideoView({super.key, required this.videoUrl});

  @override
  State<ExerciseVideoView> createState() => _ExerciseVideoViewState();
}

class _ExerciseVideoViewState extends State<ExerciseVideoView> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _player.setVolume(0);
    _player.setPlaylistMode(PlaylistMode.loop);

    if (widget.videoUrl.isNotEmpty) {
      _player.open(Media(widget.videoUrl));
    }
  }

  @override
  void didUpdateWidget(ExerciseVideoView old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl && widget.videoUrl.isNotEmpty) {
      _player.open(Media(widget.videoUrl));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white24, size: 64),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1A1A1A),
      child: Opacity(
        opacity: 0.8,
        child: Video(
          controller: _controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
