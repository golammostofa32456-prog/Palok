import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatelessWidget {
  final VideoPlayerController controller;
  final BoxFit fit;
  final bool showLoading;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.showLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller.value;

    if (!value.isInitialized) {
      if (!showLoading) {
        return const SizedBox.expand();
      }

      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF2D55),
          ),
        ),
      );
    }

    final videoWidth = value.size.width;
    final videoHeight = value.size.height;

    if (videoWidth <= 0 || videoHeight <= 0) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: fit,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoWidth,
          height: videoHeight,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
