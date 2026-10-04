import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  static const Color _pink = Color(0xFFFF2D55);

  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  int _cameraIndex = 0;

  bool _isLoading = true;
  bool _isRecording = false;
  bool _flashEnabled = false;

  int _timerSeconds = 0;
  int _countdown = 0;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _countdownTimer?.cancel();

    _controller?.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // =========================================================
  // INITIALIZE CAMERA
  // =========================================================

  Future<void> _initializeCamera({
    CameraLensDirection? targetDirection,
  }) async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera found');
      }

      // যদি নির্দিষ্ট lens চাওয়া হয়,
      // তাহলে সেই lens-এর camera খুঁজে নাও।
      if (targetDirection != null) {
        final targetIndex = _cameras.indexWhere(
          (camera) =>
              camera.lensDirection ==
              targetDirection,
        );

        if (targetIndex != -1) {
          _cameraIndex = targetIndex;
        }
      }

      if (_cameraIndex >= _cameras.length) {
        _cameraIndex = 0;
      }

      await _controller?.dispose();

      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      _controller = controller;

      await controller.initialize();

      await controller.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      await controller.setFlashMode(
        _flashEnabled
            ? FlashMode.torch
            : FlashMode.off,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        _cameraErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Camera চালু করা যায়নি।',
      );
    }
  }

  // =========================================================
  // CAMERA ERROR
  // =========================================================

  String _cameraErrorMessage(
    CameraException e,
  ) {
    switch (e.code) {
      case 'CameraAccessDenied':
        return 'Camera permission দেওয়া হয়নি.';

      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission Settings থেকে চালু করুন.';

      case 'AudioAccessDenied':
        return 'Microphone permission দেওয়া হয়নি.';

      default:
        return 'Camera চালু করা যায়নি.';
    }
  }

  // =========================================================
  // FLIP CAMERA
  // =========================================================

  Future<void> _flipCamera() async {
    if (_isRecording || _isLoading) {
      return;
    }

    if (_cameras.length < 2) {
      _showMessage(
        'এই ফোনে অন্য camera পাওয়া যায়নি.',
      );
      return;
    }

    final currentCamera =
        _cameras[_cameraIndex];

    final currentDirection =
        currentCamera.lensDirection;

    final targetDirection =
        currentDirection ==
                CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;

    final targetIndex =
        _cameras.indexWhere(
      (camera) =>
          camera.lensDirection ==
          targetDirection,
    );

    if (targetIndex == -1) {
      _showMessage(
        'অন্য camera পাওয়া যায়নি.',
      );
      return;
    }

    if (targetIndex == _cameraIndex) {
      _showMessage(
        'অন্য camera পাওয়া যায়নি.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    _cameraIndex = targetIndex;

    await _initializeCamera(
      targetDirection: targetDirection,
    );
  }

  // =========================================================
  // FLASH
  // =========================================================

  Future<void> _toggleFlash() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      _showMessage(
        'Recording চলার সময় Flash পরিবর্তন করা যাবে না.',
      );
      return;
    }

    try {
      final newValue = !_flashEnabled;

      await controller.setFlashMode(
        newValue
            ? FlashMode.torch
            : FlashMode.off,
      );

      if (!mounted) return;

      setState(() {
        _flashEnabled = newValue;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'এই camera-তে Flash control করা যায়নি.',
      );
    }
  }

  // =========================================================
  // TIMER
  // =========================================================

  Future<void> _showTimerDialog() async {
    if (_isRecording || _isLoading) {
      return;
    }

    final selected =
        await showModalBottomSheet<int>(
      context: context,
      backgroundColor:
          const Color(0xFF151515),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'Timer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                _timerOption(
                  0,
                  'Off',
                ),

                _timerOption(
                  3,
                  '3 seconds',
                ),

                _timerOption(
                  5,
                  '5 seconds',
                ),

                _timerOption(
                  10,
                  '10 seconds',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _timerSeconds = selected;
    });

    if (selected > 0) {
      _showMessage(
        'Timer: ${selected}s',
      );
    } else {
      _showMessage(
        'Timer বন্ধ',
      );
    }
  }

  Widget _timerOption(
    int seconds,
    String label,
  ) {
    final selected =
        _timerSeconds == seconds;

    return ListTile(
      onTap: () {
        Navigator.pop(
          context,
          seconds,
        );
      },
      leading: Icon(
        selected
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
        color: selected
            ? _pink
            : Colors.white54,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  // =========================================================
  // START RECORDING
  // =========================================================

  Future<void> _startRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isLoading ||
        _isRecording) {
      return;
    }

    if (_timerSeconds > 0) {
      await _startCountdown();
      return;
    }

    await _beginRecording();
  }

  // =========================================================
  // COUNTDOWN
  // =========================================================

  Future<void> _startCountdown() async {
    _countdownTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _countdown = _timerSeconds;
    });

    final completer =
        Completer<void>();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted) {
          timer.cancel();

          if (!completer.isCompleted) {
            completer.complete();
          }

          return;
        }

        if (_countdown <= 1) {
          timer.cancel();

          setState(() {
            _countdown = 0;
          });

          await _beginRecording();

          if (!completer.isCompleted) {
            completer.complete();
          }
        } else {
          setState(() {
            _countdown--;
          });
        }
      },
    );

    await completer.future;
  }

  // =========================================================
  // BEGIN RECORDING
  // =========================================================

  Future<void> _beginRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      await controller.startVideoRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = true;
      });
    } on CameraException catch (e) {
      _showMessage(
        e.description ??
            'Recording শুরু করা যায়নি.',
      );
    } catch (e) {
      _showMessage(
        'Recording শুরু করা যায়নি.',
      );
    }
  }

  // =========================================================
  // STOP RECORDING
  // =========================================================

  Future<void> _stopRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        !_isRecording) {
      return;
    }

    try {
      final XFile video =
          await controller.stopVideoRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      Navigator.of(context).pop(
        video.path,
      );
    } on CameraException catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      _showMessage(
        e.description ??
            'Recording বন্ধ করা যায়নি.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      _showMessage(
        'Video save করা যায়নি.',
      );
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // RIGHT SIDE TOOL
  // =========================================================

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: active
                  ? _pink.withOpacity(
                      0.25,
                    )
                  : Colors.black.withOpacity(
                      0.35,
                    ),
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color: active
                    ? _pink
                    : Colors.white24,
              ),
            ),
            child: Icon(
              icon,
              color: active
                  ? _pink
                  : Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CAMERA PREVIEW
  // =========================================================

  Widget _buildCameraPreview() {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child:
            CircularProgressIndicator(
          color: _pink,
        ),
      );
    }

    final previewSize =
        controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(
        controller,
      );
    }

    // তোমার ফোনে বর্তমানে যে preview
    // সঠিকভাবে দেখা যাচ্ছে সেটিই রাখা হয়েছে।
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(
              controller,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraPreview(),

            // Dark gradient
            IgnorePointer(
              child: Container(
                decoration:
                    const BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Color(0xAA000000),
                    ],
                    stops: [
                      0.0,
                      0.45,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),

            // =================================================
            // TOP
            // =================================================

            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  _circleButton(
                    icon: Icons.close,
                    onTap: () {
                      if (_isRecording) {
                        _showMessage(
                          'আগে recording বন্ধ করুন.',
                        );
                        return;
                      }

                      Navigator.pop(
                        context,
                      );
                    },
                  ),

                  const Text(
                    'PALOK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),

                  _circleButton(
                    icon:
                        Icons.settings_outlined,
                    onTap: () {
                      _showMessage(
                        'Camera settings পরে যোগ করা হবে.',
                      );
                    },
                  ),
                ],
              ),
            ),

            // =================================================
            // RIGHT SIDE
            // =================================================

            Positioned(
              right: 14,
              top: 145,
              child: Column(
                children: [
                  // FLIP
                  _toolButton(
                    icon:
                        Icons.flip_camera_ios_outlined,
                    label: 'Flip',
                    onTap:
                        _flipCamera,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // SPEED
                  _toolButton(
                    icon: Icons.speed,
                    label: 'Speed',
                    onTap: () {
                      _showMessage(
                        'Speed পরের ধাপে যোগ হবে.',
                      );
                    },
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // TIMER
                  _toolButton(
                    icon:
                        Icons.timer_outlined,
                    label:
                        _timerSeconds == 0
                            ? 'Timer'
                            : '${_timerSeconds}s',
                    onTap:
                        _showTimerDialog,
                    active:
                        _timerSeconds > 0,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // FLASH
                  _toolButton(
                    icon: _flashEnabled
                        ? Icons.flash_on
                        : Icons.flash_off,
                    label: 'Flash',
                    onTap:
                        _toggleFlash,
                    active:
                        _flashEnabled,
                  ),
                ],
              ),
            ),

            // =================================================
            // COUNTDOWN
            // =================================================

            if (_countdown > 0)
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withOpacity(
                      0.55,
                    ),
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color: _pink,
                      width: 3,
                    ),
                  ),
                  alignment:
                      Alignment.center,
                  child: Text(
                    '$_countdown',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

            // =================================================
            // RECORDING INDICATOR
            // =================================================

            if (_isRecording)
              Positioned(
                top: 72,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.red
                          .withOpacity(
                        0.85,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child:
                        const Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .fiber_manual_record,
                          color:
                              Colors.white,
                          size: 12,
                        ),
                        SizedBox(
                          width: 6,
                        ),
                        Text(
                          'REC',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // =================================================
            // BOTTOM
            // =================================================

            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceEvenly,
                    children: [
                      _bottomTool(
                        icon:
                            Icons.music_note,
                        label: 'Sound',
                        onTap: () {
                          _showMessage(
                            'Sound selection পরে যোগ হবে.',
                          );
                        },
                      ),

                      _bottomTool(
                        icon:
                            Icons.auto_awesome,
                        label: 'Effects',
                        onTap: () {
                          _showMessage(
                            'Effects editor পরে যোগ হবে.',
                          );
                        },
                      ),

                      _bottomTool(
                        icon:
                            Icons.text_fields,
                        label: 'Text',
                        onTap: () {
                          _showMessage(
                            'Text editor পরে যোগ হবে.',
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      // Gallery
                      _circleButton(
                        icon: Icons
                            .photo_library_outlined,
                        onTap: () {
                          _showMessage(
                            'Gallery থেকে নিতে হলে Create screen-এর Gallery ব্যবহার করুন.',
                          );
                        },
                      ),

                      const SizedBox(
                        width: 34,
                      ),

                      // RECORD BUTTON
                      GestureDetector(
                        onTap: _isRecording
                            ? _stopRecording
                            : _startRecording,
                        child:
                            AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds:
                                180,
                          ),
                          width:
                              _isRecording
                                  ? 76
                                  : 82,
                          height:
                              _isRecording
                                  ? 76
                                  : 82,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            border:
                                Border.all(
                              color:
                                  Colors.white,
                              width: 5,
                            ),
                          ),
                          child: Center(
                            child:
                                AnimatedContainer(
                              duration:
                                  const Duration(
                                milliseconds:
                                    180,
                              ),
                              width:
                                  _isRecording
                                      ? 30
                                      : 64,
                              height:
                                  _isRecording
                                      ? 30
                                      : 64,
                              decoration:
                                  BoxDecoration(
                                color:
                                    _pink,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  _isRecording
                                      ? 7
                                      : 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 34,
                      ),

                      // CHECK
                      _circleButton(
                        icon:
                            Icons.check,
                        onTap: () {
                          if (_isRecording) {
                            _stopRecording();
                          } else {
                            _showMessage(
                              'আগে একটি video record করুন.',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // =================================================
            // LOADING
            // =================================================

            if (_isLoading)
              Container(
                color: Colors.black54,
                child:
                    const Center(
                  child:
                      CircularProgressIndicator(
                    color: _pink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BOTTOM TOOL
  // =========================================================

  Widget _bottomTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CIRCLE BUTTON
  // =========================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(
          color: Colors.black
              .withOpacity(0.35),
          shape:
              BoxShape.circle,
          border:
              Border.all(
            color: Colors.white24,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
