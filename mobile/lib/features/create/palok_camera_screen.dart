import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'create_tools.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  static const Color _pink = kPalokPink;

  final ImagePicker _picker = ImagePicker();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  bool _isLoading = true;
  bool _isRecording = false;
  bool _stopping = false;
  bool _flashEnabled = false;

  bool _initializing = false;
  bool _reinitRequested = false;
  CameraLensDirection? _pendingDirection;

  CreateSettings _settings = CreateSettingsStore.current;

  int _timerSeconds = 0;
  int _countdown = 0;
  double _speed = 1.0;
  int _recSeconds = 0;

  String _effectId = 'none';
  final List<TextOverlay> _texts = <TextOverlay>[];

  String? _soundPath;
  String _soundName = '';
  VideoPlayerController? _soundPlayer;

  Timer? _countdownTimer;
  Timer? _recTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    final s = await CreateSettingsStore.load();
    if (!mounted) return;
    _settings = s;
    _timerSeconds = s.defaultTimer;
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _recTimer?.cancel();
    _soundPlayer?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_isRecording) return;
      final c = _controller;
      if (c == null) return;
      _controller = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_isLoading) {
        _initializeCamera();
      }
    }
  }

  // =========================================================
  // CAMERA
  // =========================================================

  ResolutionPreset _preset() {
    switch (_settings.cameraQuality) {
      case 0:
        return ResolutionPreset.medium;
      case 2:
        return ResolutionPreset.veryHigh;
      default:
        return ResolutionPreset.high;
    }
  }

  Future<void> _initializeCamera({
    CameraLensDirection? targetDirection,
  }) async {
    if (_initializing) {
      _reinitRequested = true;
      if (targetDirection != null) _pendingDirection = targetDirection;
      return;
    }

    _initializing = true;

    try {
      if (mounted) setState(() => _isLoading = true);

      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No camera found');

      if (targetDirection != null) {
        final idx = _cameras.indexWhere(
          (c) => c.lensDirection == targetDirection,
        );
        if (idx != -1) _cameraIndex = idx;
      }

      if (_cameraIndex >= _cameras.length) _cameraIndex = 0;

      final old = _controller;
      _controller = null;
      await old?.dispose();

      final controller = CameraController(
        _cameras[_cameraIndex],
        _preset(),
        // সাউন্ড বাছা থাকলে মাইক বন্ধ (সাউন্ডটাই ভিডিওর অডিও হবে)
        enableAudio: _soundPath == null,
      );

      _controller = controller;

      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(
        _flashEnabled ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(_cameraErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Camera চালু করা যায়নি।');
    } finally {
      _initializing = false;
      if (_reinitRequested && mounted) {
        _reinitRequested = false;
        final d = _pendingDirection;
        _pendingDirection = null;
        unawaited(_initializeCamera(targetDirection: d));
      }
    }
  }

  String _cameraErrorMessage(CameraException e) {
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

  Future<void> _flipCamera() async {
    if (_isRecording || _isLoading) return;

    if (_cameras.length < 2) {
      _showMessage('এই ফোনে অন্য camera পাওয়া যায়নি.');
      return;
    }

    final current = _cameras[_cameraIndex].lensDirection;
    final target = current == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final idx = _cameras.indexWhere((c) => c.lensDirection == target);
    if (idx == -1 || idx == _cameraIndex) {
      _showMessage('অন্য camera পাওয়া যায়নি.');
      return;
    }

    _cameraIndex = idx;
    await _initializeCamera(targetDirection: target);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_isRecording) {
      _showMessage('Recording চলার সময় Flash পরিবর্তন করা যাবে না.');
      return;
    }

    try {
      final newValue = !_flashEnabled;
      await controller.setFlashMode(
        newValue ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() => _flashEnabled = newValue);
    } catch (e) {
      _showMessage('এই camera-তে Flash control করা যায়নি.');
    }
  }

  // =========================================================
  // TIMER / SPEED
  // =========================================================

  Widget _optionTile<T>({
    required T value,
    required T selected,
    required String title,
    String? subtitle,
  }) {
    final isSelected = value == selected;
    return ListTile(
      onTap: () => Navigator.pop(context, value),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? _pink : Colors.white54,
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
    );
  }

  Future<T?> _pickSheet<T>(String title, List<Widget> children) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTimerDialog() async {
    if (_isRecording || _isLoading) return;

    final selected = await _pickSheet<int>('Timer', [
      _optionTile<int>(value: 0, selected: _timerSeconds, title: 'Off'),
      _optionTile<int>(value: 3, selected: _timerSeconds, title: '3 seconds'),
      _optionTile<int>(value: 5, selected: _timerSeconds, title: '5 seconds'),
      _optionTile<int>(
          value: 10, selected: _timerSeconds, title: '10 seconds'),
    ]);

    if (selected == null || !mounted) return;

    setState(() => _timerSeconds = selected);
    _showMessage(selected > 0 ? 'Timer: ${selected}s' : 'Timer বন্ধ');
  }

  String _speedLabel(double s) {
    if (s == 0.5) return '0.5x';
    if (s == 2.0) return '2x';
    return '1x';
  }

  Future<void> _showSpeedDialog() async {
    if (_isRecording || _isLoading) return;

    final selected = await _pickSheet<double>('Speed', [
      _optionTile<double>(
          value: 0.5, selected: _speed, title: '0.5x', subtitle: 'Slow'),
      _optionTile<double>(
          value: 1.0, selected: _speed, title: '1x', subtitle: 'Normal'),
      _optionTile<double>(
          value: 2.0, selected: _speed, title: '2x', subtitle: 'Fast'),
    ]);

    if (selected == null || !mounted) return;

    setState(() => _speed = selected);
    _showMessage('Speed: ${_speedLabel(selected)}');
  }

  // =========================================================
  // EFFECTS / TEXT / SOUND / SETTINGS
  // =========================================================

  Future<void> _showEffects() async {
    if (_isRecording) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Effects',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: kCreateEffects.map((e) {
                  final active = e.id == _effectId;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, e.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _pink : Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        e.label,
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
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _effectId = selected);
  }

  Future<void> _addText() async {
    if (_isRecording) return;

    if (_texts.length >= 5) {
      _showMessage('সর্বোচ্চ ৫টি লেখা যোগ করা যাবে।');
      return;
    }

    final result = await showTextEditor(context);
    if (result == null || result.text.isEmpty || !mounted) return;
    setState(() => _texts.add(result));
  }

  Future<void> _editText(TextOverlay t) async {
    if (_isRecording) return;

    final result = await showTextEditor(context, initial: t);
    if (result == null || !mounted) return;

    setState(() {
      if (result.text.isEmpty) {
        _texts.removeWhere((x) => x.id == t.id);
      } else {
        t.text = result.text;
        t.colorValue = result.colorValue;
        t.size = result.size;
      }
    });
  }

  Future<void> _showSoundSheet() async {
    if (_isRecording) return;

    final action = await _pickSheet<String>('Sound', [
      ListTile(
        onTap: () => Navigator.pop(context, 'pick'),
        leading: const Icon(Icons.library_music, color: Colors.white),
        title: Text(
          _soundPath == null ? 'ফোন থেকে সাউন্ড বাছুন' : 'অন্য সাউন্ড বাছুন',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: const Text(
          'রেকর্ডের সময় মাইক বন্ধ থাকবে, সাউন্ডটি ভিডিওতে যোগ হবে',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
      if (_soundPath != null)
        ListTile(
          onTap: () => Navigator.pop(context, 'remove'),
          leading: const Icon(Icons.delete_outline, color: _pink),
          title: Text(
            'সরান: $_soundName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _pink),
          ),
        ),
    ]);

    if (!mounted) return;

    if (action == 'pick') {
      final picked = await pickSoundFromDevice();
      if (picked == null || !mounted) return;
      await _setSound(picked.path, picked.name);
    } else if (action == 'remove') {
      await _clearSound();
    }
  }

  Future<void> _setSound(String path, String name) async {
    final old = _soundPlayer;
    _soundPlayer = null;
    await old?.dispose();

    try {
      final player = VideoPlayerController.file(File(path));
      await player.initialize();
      await player.setLooping(true);
      _soundPlayer = player;
    } catch (e) {
      _showMessage('এই সাউন্ড ফাইল চালানো যায়নি।');
      return;
    }

    if (!mounted) return;

    setState(() {
      _soundPath = path;
      _soundName = name;
    });

    // মাইক বন্ধ করে ক্যামেরা আবার চালু
    await _initializeCamera();
    _showMessage('Sound বাছা হয়েছে।');
  }

  Future<void> _clearSound() async {
    final old = _soundPlayer;
    _soundPlayer = null;
    await old?.dispose();

    if (!mounted) return;

    setState(() {
      _soundPath = null;
      _soundName = '';
    });

    await _initializeCamera();
  }

  Future<void> _startSound() async {
    final p = _soundPlayer;
    if (p == null) return;
    try {
      await p.seekTo(Duration.zero);
      await p.play();
    } catch (_) {}
  }

  Future<void> _stopSound() async {
    try {
      await _soundPlayer?.pause();
    } catch (_) {}
  }

  Future<void> _openSettings() async {
    if (_isRecording || _isLoading) return;

    final beforeQuality = _settings.cameraQuality;
    final beforeTimer = _settings.defaultTimer;

    final s = await showCreateSettingsSheet(context);
    if (!mounted) return;

    setState(() {
      _settings = s;
      if (s.defaultTimer != beforeTimer) _timerSeconds = s.defaultTimer;
    });

    if (s.cameraQuality != beforeQuality) {
      await _initializeCamera();
    }
  }

  // =========================================================
  // GALLERY
  // =========================================================

  Future<void> _pickFromGallery() async {
    if (_isRecording || _isLoading) return;

    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(seconds: _settings.maxSeconds),
      );

      if (file == null || !mounted) return;

      Navigator.of(context).pop(
        CameraResult(path: file.path, edits: _buildEdits()),
      );
    } catch (e) {
      _showMessage('ভিডিও নির্বাচন করা যায়নি.');
    }
  }

  CreateEdits _buildEdits() {
    return CreateEdits(
      effectId: _effectId,
      speed: _speed,
      soundPath: _soundPath,
      soundName: _soundName,
      texts: List<TextOverlay>.from(_texts),
    );
  }

  // =========================================================
  // RECORDING
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

  Future<void> _startCountdown() async {
    _countdownTimer?.cancel();
    if (!mounted) return;

    setState(() => _countdown = _timerSeconds);

    final completer = Completer<void>();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
          return;
        }

        if (_countdown <= 1) {
          timer.cancel();
          setState(() => _countdown = 0);
          await _beginRecording();
          if (!completer.isCompleted) completer.complete();
        } else {
          setState(() => _countdown--);
        }
      },
    );

    await completer.future;
  }

  Future<void> _beginRecording() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.startVideoRecording();
      unawaited(_startSound());

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recSeconds = 0;
      });

      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        setState(() => _recSeconds++);

        if (_recSeconds >= _settings.maxSeconds) {
          t.cancel();
          _stopRecording();
        }
      });
    } on CameraException catch (e) {
      _showMessage(e.description ?? 'Recording শুরু করা যায়নি.');
    } catch (e) {
      _showMessage('Recording শুরু করা যায়নি.');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        !_isRecording ||
        _stopping) {
      return;
    }

    _stopping = true;
    _recTimer?.cancel();

    try {
      final XFile video = await controller.stopVideoRecording();
      await _stopSound();

      if (!mounted) return;

      setState(() => _isRecording = false);

      Navigator.of(context).pop(
        CameraResult(
          path: video.path,
          edits: _buildEdits(),
          // সাউন্ড বাছা থাকলে ভিডিওতে মূল অডিও নেই
          hasOriginalAudio: _soundPath == null,
        ),
      );
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _isRecording = false);
      _showMessage(e.description ?? 'Recording বন্ধ করা যায়নি.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecording = false);
      _showMessage('Video save করা যায়নি.');
    } finally {
      _stopping = false;
    }
  }

  // =========================================================
  // UI HELPERS
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active
                  ? _pink.withOpacity(0.25)
                  : Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: active ? _pink : Colors.white24),
            ),
            child: Icon(
              icon,
              color: active ? _pink : Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
    bool active = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? _pink : Colors.white, size: 24),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: active ? _pink : Colors.white,
              fontSize: 11,
            ),
          ),
        ],
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // =========================================================
  // PREVIEW
  // =========================================================

  Widget _buildCameraPreview() {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: _pink),
      );
    }

    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final aspect = previewSize.height / previewSize.width;

    Widget preview = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );

    final cf = effectById(_effectId).colorFilter;
    if (cf != null) {
      preview = ColorFiltered(colorFilter: cf, child: preview);
    }

    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (context, box) {
            return Stack(
              fit: StackFit.expand,
              children: [
                preview,
                if (_settings.grid)
                  const IgnorePointer(
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                for (final t in _texts)
                  createTextLayer(
                    overlay: t,
                    width: box.maxWidth,
                    height: box.maxHeight,
                    onTap: () => _editText(t),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraPreview(),

            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Color(0xAA000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // ---------------- TOP ----------------
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleButton(
                    icon: Icons.close,
                    onTap: () {
                      if (_isRecording) {
                        _showMessage('আগে recording বন্ধ করুন.');
                        return;
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    'PALOK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  _circleButton(
                    icon: Icons.settings_outlined,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),

            // ---------------- SOUND CHIP ----------------
            if (_soundPath != null && !_isRecording)
              Positioned(
                top: 68,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _soundName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ---------------- RIGHT TOOLS ----------------
            Positioned(
              right: 14,
              top: 145,
              child: Column(
                children: [
                  _toolButton(
                    icon: Icons.flip_camera_ios_outlined,
                    label: 'Flip',
                    onTap: _flipCamera,
                  ),
                  const SizedBox(height: 20),
                  _toolButton(
                    icon: Icons.speed,
                    label: _speedLabel(_speed),
                    onTap: _showSpeedDialog,
                    active: _speed != 1.0,
                  ),
                  const SizedBox(height: 20),
                  _toolButton(
                    icon: Icons.timer_outlined,
                    label: _timerSeconds == 0 ? 'Timer' : '${_timerSeconds}s',
                    onTap: _showTimerDialog,
                    active: _timerSeconds > 0,
                  ),
                  const SizedBox(height: 20),
                  _toolButton(
                    icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                    label: 'Flash',
                    onTap: _toggleFlash,
                    active: _flashEnabled,
                  ),
                ],
              ),
            ),

            // ---------------- COUNTDOWN ----------------
            if (_countdown > 0)
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: _pink, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            // ---------------- REC ----------------
            if (_isRecording)
              Positioned(
                top: 72,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'REC ${_formatTime(_recSeconds)} / '
                          '${_formatTime(_settings.maxSeconds)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ---------------- BOTTOM ----------------
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bottomTool(
                        icon: Icons.music_note,
                        label: 'Sound',
                        onTap: _showSoundSheet,
                        active: _soundPath != null,
                      ),
                      _bottomTool(
                        icon: Icons.auto_awesome,
                        label: 'Effects',
                        onTap: _showEffects,
                        active: _effectId != 'none',
                      ),
                      _bottomTool(
                        icon: Icons.text_fields,
                        label: 'Text',
                        onTap: _addText,
                        active: _texts.isNotEmpty,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _circleButton(
                        icon: Icons.photo_library_outlined,
                        onTap: _pickFromGallery,
                      ),
                      const SizedBox(width: 34),
                      GestureDetector(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: _isRecording ? 76 : 82,
                          height: _isRecording ? 76 : 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 5),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: _isRecording ? 30 : 64,
                              height: _isRecording ? 30 : 64,
                              decoration: BoxDecoration(
                                color: _pink,
                                borderRadius: BorderRadius.circular(
                                  _isRecording ? 7 : 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 34),
                      _circleButton(
                        icon: Icons.check,
                        onTap: () {
                          if (_isRecording) {
                            _stopRecording();
                          } else {
                            _showMessage('আগে একটি video record করুন.');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: _pink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;

    for (var i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
