import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays a muted, looping 3D animation behind [child] based on the
/// workout category. If no video is mapped for that category, the
/// child is returned unchanged so existing screens still work.
class CategoryVideoBackground extends StatefulWidget {
  final String category;
  final Widget child;
  final double opacity;

  const CategoryVideoBackground({
    super.key,
    required this.category,
    required this.child,
    this.opacity = 0.35,
  });

  static const categoryVideos = {
    'legs': 'assets/videos/legs.mp4',
    'abs': 'assets/videos/abs.mp4',
    'arms': 'assets/videos/arms.mp4',
    'back': 'assets/videos/back.mp4',
    'bodyweight': 'assets/videos/bodyweight.mp4',
    'calisthenics': 'assets/videos/bodyweight.mp4',
    'cardio': 'assets/videos/cardio.mp4',
    'chest': 'assets/videos/chest.mp4',
    'custom': 'assets/videos/custom.mp4',
  };

  @override
  State<CategoryVideoBackground> createState() =>
      _CategoryVideoBackgroundState();
}

class _CategoryVideoBackgroundState extends State<CategoryVideoBackground> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final path = CategoryVideoBackground.categoryVideos[widget.category];
    if (path != null) {
      _controller = VideoPlayerController.asset(path)
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (!mounted) return;
          _controller!.play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_controller != null && _controller!.value.isInitialized)
          Positioned.fill(
            child: Opacity(
              opacity: widget.opacity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}
