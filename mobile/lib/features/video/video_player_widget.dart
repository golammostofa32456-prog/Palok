
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatelessWidget {
  final VideoPlayerController controller;
  final BoxFit fit;
  final bool showLoading;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
    this.showLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      if (!showLoading) {
        return const SizedBox.expand();
      }

      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
