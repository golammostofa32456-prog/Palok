import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  final ImagePicker _picker = ImagePicker();

  VideoPlayerController? _videoController;
  XFile? _selectedVideo;

  bool _isLoading = false;

  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );

      if (file == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      await _videoController?.dispose();

      final controller = VideoPlayerController.file(
        
        File(file.path),
      );

      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _selectedVideo = file;
        _videoController = controller;
        _isLoading = false;
      });

      await controller.play();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ভিডিও নির্বাচন করা যায়নি: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _closeScreen() {
    Navigator.of(context).pop();
  }

  void _showSoundMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sound feature পরে যোগ করা হবে'),
        backgroundColor: Colors.black87,
      ),
    );
  }

  void _continueWithVideo() {
    if (_selectedVideo == null) return;

    Navigator.of(context).pop(_selectedVideo!.path);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final hasVideo =
        controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ---------------------------------------------------------
            // VIDEO / CAMERA BACKGROUND
            // ---------------------------------------------------------
            if (hasVideo)
              GestureDetector(
                onTap: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }

                  setState(() {});
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF151515),
                      Color(0xFF050505),
                      Colors.black,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white24,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.videocam_outlined,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Create on PALOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Record বা Gallery থেকে ভিডিও তৈরি করুন',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ---------------------------------------------------------
            // TOP GRADIENT
            // ---------------------------------------------------------
            IgnorePointer(
              child: Container(
                height: 190,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ---------------------------------------------------------
            // BOTTOM GRADIENT
            // ---------------------------------------------------------
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 280,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ---------------------------------------------------------
            // TOP BAR
            // ---------------------------------------------------------
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleButton(
                    icon: Icons.close,
                    onTap: _closeScreen,
                  ),
                  const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _circleButton(
                    icon: Icons.settings_outlined,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------------
            // SIDE TOOLS
            // ---------------------------------------------------------
            if (hasVideo)
              Positioned(
                right: 14,
                top: MediaQuery.of(context).size.height * 0.32,
                child: Column(
                  children: [
                    _sideTool(
                      icon: Icons.flip_camera_ios_outlined,
                      label: 'Flip',
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: Icons.speed,
                      label: 'Speed',
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: Icons.timer_outlined,
                      label: 'Timer',
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: Icons.flash_on_outlined,
                      label: 'Flash',
                      onTap: () {},
                    ),
                  ],
                ),
              ),

            // ---------------------------------------------------------
            // LOADING
            // ---------------------------------------------------------
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: _pink,
                ),
              ),

            // ---------------------------------------------------------
            // BOTTOM CONTROLS
            // ---------------------------------------------------------
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Column(
                children: [
                  if (hasVideo)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 18,
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _bottomTool(
                            icon: Icons.music_note,
                            label: 'Sound',
                            onTap: _showSoundMessage,
                          ),
                          _bottomTool(
                            icon: Icons.auto_awesome,
                            label: 'Effects',
                            onTap: () {},
                          ),
                          _bottomTool(
                            icon: Icons.text_fields,
                            label: 'Text',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _galleryButton(),

                      GestureDetector(
                        onTap: hasVideo
                            ? () {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                                setState(() {});
                              }
                            : () => _pickVideo(ImageSource.camera),
                        child: Container(
                          width: 82,
                          height: 82,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasVideo
                                  ? _pink
                                  : Colors.white,
                            ),
                            child: Icon(
                              hasVideo
                                  ? (controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow)
                                  : Icons.camera_alt,
                              color: hasVideo
                                  ? Colors.white
                                  : Colors.black,
                              size: 34,
                            ),
                          ),
                        ),
                      ),

                      if (hasVideo)
                        GestureDetector(
                          onTap: _continueWithVideo,
                          child: Container(
                            width: 64,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _pink,
                              borderRadius:
                                  BorderRadius.circular(22),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 64),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'ভিডিও সর্বোচ্চ ৩ মিনিট',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white24,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }

  Widget _sideTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 25,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryButton() {
    return GestureDetector(
      onTap: () => _pickVideo(ImageSource.gallery),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white38,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
              size: 25,
            ),
            SizedBox(height: 2),
            Text(
              'Gallery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
