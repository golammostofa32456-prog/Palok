import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_player_widget.dart';
import 'video_post.dart';

class VideoPage extends StatelessWidget {
  final VideoPost video;
  final VideoPlayerController? controller;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  final Widget topBar;
  final Widget rightActions;
  final Widget videoInfo;

  const VideoPage({
    super.key,
    required this.video,
    required this.controller,
    required this.topBar,
    required this.rightActions,
    required this.videoInfo,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideo(),

          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),

          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Color(0xB8000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),

          topBar,
          rightActions,
          videoInfo,
        ],
      ),
    );
  }

  Widget _buildVideo() {
    final videoController = controller;

    if (videoController != null &&
        videoController.value.isInitialized) {
      return VideoPlayerWidget(
        controller: videoController,
        fit: BoxFit.cover,
      );
    }

    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}
