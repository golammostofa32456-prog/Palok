import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palok/features/create/camera_screen.dart';
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
  bool _isFlipped = false;
  bool _isMuted = false;
  bool _flashEnabled = false;

  double _playbackSpeed = 1.0;

  int _timerSeconds = 0;
  int _countdown = 0;

  String _selectedEffect = 'None';
  String _overlayText = '';

  Timer? _countdownTimer;

  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // PICK VIDEO FROM GALLERY
  // ---------------------------------------------------------

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
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _selectedVideo = file;
        _videoController = controller;
        _isLoading = false;
        _isFlipped = false;
        _isMuted = false;
        _flashEnabled = false;
        _playbackSpeed = 1.0;
        _timerSeconds = 0;
        _countdown = 0;
        _selectedEffect = 'None';
        _overlayText = '';
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

  // ---------------------------------------------------------
  // OPEN REAL PALOK CAMERA
  // ---------------------------------------------------------

  Future<void> _openCamera() async {
    if (_isLoading) return;

    final String? videoPath =
        await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(),
      ),
    );

    if (videoPath == null || !mounted) return;

    await _loadVideoFromPath(videoPath);
  }

  // ---------------------------------------------------------
  // LOAD VIDEO FROM REAL CAMERA
  // ---------------------------------------------------------

  Future<void> _loadVideoFromPath(String path) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final file = XFile(path);

      await _videoController?.dispose();

      final controller = VideoPlayerController.file(
        File(path),
      );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(
        _isMuted ? 0.0 : 1.0,
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _selectedVideo = file;
        _videoController = controller;
        _isLoading = false;

        _isFlipped = false;
        _isMuted = false;
        _flashEnabled = false;

        _playbackSpeed = 1.0;
        _timerSeconds = 0;
        _countdown = 0;

        _selectedEffect = 'None';
        _overlayText = '';
      });

      await controller.play();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Camera video load করা যায়নি: $e',
      );
    }
  }

  // ---------------------------------------------------------
  // CLOSE
  // ---------------------------------------------------------

  void _closeScreen() {
    _countdownTimer?.cancel();
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------
  // PLAY / PAUSE
  // ---------------------------------------------------------

  Future<void> _togglePlay() async {
    final controller = _videoController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------
  // FLIP
  // ---------------------------------------------------------

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });

    _showMessage(
      _isFlipped
          ? 'ভিডিও Flip করা হয়েছে'
          : 'Flip বন্ধ করা হয়েছে',
    );
  }

  // ---------------------------------------------------------
  // SPEED
  // ---------------------------------------------------------

  Future<void> _showSpeedDialog() async {
    final controller = _videoController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        final speeds = <double>[
          0.5,
          0.75,
          1.0,
          1.25,
          1.5,
          2.0,
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Playback Speed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: speeds.map((speed) {
                    final active = _playbackSpeed == speed;

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(speed);
                      },
                      child: Container(
                        width: 82,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? _pink
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active
                                ? _pink
                                : Colors.white24,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${speed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _playbackSpeed = selected;
    });

    await controller.setPlaybackSpeed(selected);

    _showMessage(
      'Speed ${selected}x করা হয়েছে',
    );
  }

  // ---------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------

  Future<void> _showTimerDialog() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        final timers = <int>[0, 3, 5, 10];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Timer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ভিডিও preview শুরু হওয়ার আগে countdown',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: timers.map((seconds) {
                    final active = _timerSeconds == seconds;

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(seconds);
                      },
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? _pink
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          seconds == 0
                              ? 'Off'
                              : '${seconds}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _timerSeconds = selected;
    });

    if (selected == 0) {
      _countdownTimer?.cancel();

      setState(() {
        _countdown = 0;
      });

      _showMessage('Timer বন্ধ করা হয়েছে');
      return;
    }

    _startCountdown(selected);
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();

    setState(() {
      _countdown = seconds;
    });

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_countdown <= 1) {
          timer.cancel();

          setState(() {
            _countdown = 0;
          });

          _showMessage('Timer শেষ');
          return;
        }

        setState(() {
          _countdown--;
        });
      },
    );
  }

  // ---------------------------------------------------------
  // FLASH
  // ---------------------------------------------------------

  void _toggleFlash() {
    setState(() {
      _flashEnabled = !_flashEnabled;
    });

    _showMessage(
      _flashEnabled
          ? 'Flash preview চালু হয়েছে'
          : 'Flash বন্ধ করা হয়েছে',
    );
  }

  // ---------------------------------------------------------
  // SOUND
  // ---------------------------------------------------------

  Future<void> _toggleSound() async {
    final controller = _videoController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
    });

    await controller.setVolume(
      _isMuted ? 0.0 : 1.0,
    );

    _showMessage(
      _isMuted
          ? 'Sound mute করা হয়েছে'
          : 'Sound চালু হয়েছে',
    );
  }

  // ---------------------------------------------------------
  // EFFECTS
  // ---------------------------------------------------------

  Future<void> _showEffectsDialog() async {
    final effects = <String>[
      'None',
      'Dark',
      'Warm',
      'Cool',
      'Pink',
      'Cyan',
      'B&W',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Effects',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: effects.map((effect) {
                    final active =
                        _selectedEffect == effect;

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(effect);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? _pink
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          effect,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedEffect = selected;
    });

    _showMessage(
      selected == 'None'
          ? 'Effect বন্ধ করা হয়েছে'
          : '$selected effect চালু হয়েছে',
    );
  }

  // ---------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------

  Future<void> _showTextDialog() async {
    final controller = TextEditingController(
      text: _overlayText,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          title: const Text(
            'Add Text',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'ভিডিওতে Text লিখুন',
              hintStyle: const TextStyle(
                color: Colors.white38,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Colors.white24,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _pink,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop('');
              },
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(
                  controller.text.trim(),
                );
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: _pink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _overlayText = result;
    });

    _showMessage(
      result.isEmpty
          ? 'Text সরানো হয়েছে'
          : 'Text যোগ করা হয়েছে',
    );
  }

  // ---------------------------------------------------------
  // CONTINUE
  // ---------------------------------------------------------

  void _continueWithVideo() {
    if (_selectedVideo == null) return;

    _countdownTimer?.cancel();

    Navigator.of(context).pop(
      _selectedVideo!.path,
    );
  }

  // ---------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: const Duration(
            milliseconds: 1200,
          ),
        ),
      );
  }

  // ---------------------------------------------------------
  // EFFECT FILTER
  // ---------------------------------------------------------

  Widget _applyEffect(Widget child) {
    switch (_selectedEffect) {
      case 'Dark':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(.28),
            BlendMode.darken,
          ),
          child: child,
        );

      case 'Warm':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.orange.withOpacity(.20),
            BlendMode.overlay,
          ),
          child: child,
        );

      case 'Cool':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.blue.withOpacity(.20),
            BlendMode.overlay,
          ),
          child: child,
        );

      case 'Pink':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            _pink.withOpacity(.18),
            BlendMode.overlay,
          ),
          child: child,
        );

      case 'Cyan':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            _cyan.withOpacity(.18),
            BlendMode.overlay,
          ),
          child: child,
        );

      case 'B&W':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(
            <double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ],
          ),
          child: child,
        );

      case 'None':
      default:
        return child;
    }
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;

    final hasVideo =
        controller != null &&
        controller.value.isInitialized;

    Widget videoWidget;

    if (hasVideo) {
      videoWidget = Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(
                _isFlipped ? -1.0 : 1.0,
                1.0,
              ),
            child: VideoPlayer(controller),
          ),
        ),
      );

      videoWidget = _applyEffect(videoWidget);

      videoWidget = GestureDetector(
        onTap: _togglePlay,
        child: videoWidget,
      );
    } else {
      videoWidget = Container(
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
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            videoWidget,

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

            // ---------------------------------------------------
            // TOP BAR
            // ---------------------------------------------------

            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
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
                    onTap: () {
                      _showMessage(
                        'Create settings পরে যোগ করা যাবে',
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------
            // SIDE TOOLS
            // ---------------------------------------------------

            if (hasVideo)
              Positioned(
                right: 14,
                top: MediaQuery.of(context).size.height * 0.32,
                child: Column(
                  children: [
                    _sideTool(
                      icon: Icons.flip_camera_ios_outlined,
                      label: 'Flip',
                      onTap: _toggleFlip,
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: Icons.speed,
                      label: 'Speed',
                      onTap: _showSpeedDialog,
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: Icons.timer_outlined,
                      label: 'Timer',
                      onTap: _showTimerDialog,
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: _flashEnabled
                          ? Icons.flash_on
                          : Icons.flash_off_outlined,
                      label: 'Flash',
                      onTap: _toggleFlash,
                    ),
                  ],
                ),
              ),

            // ---------------------------------------------------
            // FLASH PREVIEW
            // ---------------------------------------------------

            if (_flashEnabled && hasVideo)
              IgnorePointer(
                child: Container(
                  color: Colors.white.withOpacity(.12),
                ),
              ),

            // ---------------------------------------------------
            // TEXT OVERLAY
            // ---------------------------------------------------

            if (_overlayText.trim().isNotEmpty)
              Positioned(
                left: 30,
                right: 30,
                top: MediaQuery.of(context).size.height * 0.25,
                child: IgnorePointer(
                  child: Text(
                    _overlayText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ---------------------------------------------------
            // COUNTDOWN
            // ---------------------------------------------------

            if (_countdown > 0)
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white54,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),

            // ---------------------------------------------------
            // LOADING
            // ---------------------------------------------------

            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: _pink,
                ),
              ),

            // ---------------------------------------------------
            // BOTTOM CONTROLS
            // ---------------------------------------------------

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
                            icon: _isMuted
                                ? Icons.volume_off
                                : Icons.music_note,
                            label: 'Sound',
                            onTap: _toggleSound,
                          ),
                          _bottomTool(
                            icon: Icons.auto_awesome,
                            label: 'Effects',
                            onTap: _showEffectsDialog,
                          ),
                          _bottomTool(
                            icon: Icons.text_fields,
                            label: 'Text',
                            onTap: _showTextDialog,
                          ),
                        ],
                      ),
                    ),

                  // -------------------------------------------------
                  // MAIN BUTTON ROW
                  // -------------------------------------------------

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      _galleryButton(),

                      GestureDetector(
                        onTap: hasVideo
                            ? _togglePlay
                            : _openCamera,
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

  // ---------------------------------------------------------
  // CIRCLE BUTTON
  // ---------------------------------------------------------

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

  // ---------------------------------------------------------
  // SIDE TOOL
  // ---------------------------------------------------------

  Widget _sideTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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

  // ---------------------------------------------------------
  // BOTTOM TOOL
  // ---------------------------------------------------------

  Widget _bottomTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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

  // ---------------------------------------------------------
  // GALLERY BUTTON
  // ---------------------------------------------------------

  Widget _galleryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _pickVideo(
          ImageSource.gallery,
        );
      },
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
