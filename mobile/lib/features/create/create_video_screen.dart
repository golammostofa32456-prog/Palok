import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palok/features/create/palok_camera_screen.dart';
import 'package:video_player/video_player.dart';

import 'create_tools.dart';

class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  static const Color _pink = kPalokPink;

  final ImagePicker _picker = ImagePicker();

  VideoPlayerController? _videoController;
  VideoPlayerController? _audioController;
  XFile? _selectedVideo;

  bool _isLoading = false;
  bool _exporting = false;

  String _effectId = 'none';
  double _speed = 1.0;
  bool _flip = false;
  bool _originalAudio = true;
  bool _hasOriginalAudio = true;
  String? _soundPath;
  String _soundName = '';
  double _soundVolume = 1.0;
  final List<TextOverlay> _texts = <TextOverlay>[];

  Duration _lastPos = Duration.zero;

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _audioController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // PLAYERS
  // ---------------------------------------------------------

  Future<void> _releasePlayers() async {
    final v = _videoController;
    final a = _audioController;
    _videoController = null;
    _audioController = null;
    v?.removeListener(_onVideoTick);
    await v?.dispose();
    await a?.dispose();
  }

  // ভিডিও ও সাউন্ড একসাথে চালানো/থামানো/লুপে সিঙ্ক রাখা
  void _onVideoTick() {
    final v = _videoController;
    final a = _audioController;
    if (v == null || a == null) return;
    if (!v.value.isInitialized || !a.value.isInitialized) return;

    final pos = v.value.position;
    if (pos + const Duration(milliseconds: 400) < _lastPos) {
      a.seekTo(Duration.zero);
    }
    _lastPos = pos;

    if (v.value.isPlaying != a.value.isPlaying) {
      if (v.value.isPlaying) {
        a.play();
      } else {
        a.pause();
      }
    }
  }

  Future<void> _prepareAudio() async {
    final old = _audioController;
    _audioController = null;
    await old?.dispose();

    final p = _soundPath;
    if (p == null) return;

    try {
      final a = VideoPlayerController.file(File(p));
      await a.initialize();
      await a.setLooping(true);
      await a.setVolume(_soundVolume);
      await a.setPlaybackSpeed(_speed);
      _audioController = a;
    } catch (_) {
      _soundPath = null;
      _soundName = '';
      _showMessage('সাউন্ড ফাইল চালানো যায়নি');
    }
  }

  // ---------------------------------------------------------
  // LOAD VIDEO
  // ---------------------------------------------------------

  Future<void> _loadVideo(String path, {CameraResult? from}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _releasePlayers();

      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final e = from?.edits;

      _selectedVideo = XFile(path);
      _effectId = e?.effectId ?? 'none';
      _speed = e?.speed ?? 1.0;
      _flip = false;
      _originalAudio = true;
      _hasOriginalAudio = from?.hasOriginalAudio ?? true;
      _soundPath = e?.soundPath;
      _soundName = e?.soundName ?? '';
      _soundVolume = e?.soundVolume ?? 1.0;
      _texts
        ..clear()
        ..addAll(e?.texts ?? <TextOverlay>[]);
      _lastPos = Duration.zero;

      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(1.0);

      _videoController = controller;
      controller.addListener(_onVideoTick);

      await _prepareAudio();

      if (!mounted) return;

      setState(() => _isLoading = false);

      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('ভিডিও লোড করা যায়নি: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isLoading || _exporting) return;

    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );

      if (file == null || !mounted) return;

      await _loadVideo(file.path);
    } catch (e) {
      _showMessage('ভিডিও নির্বাচন করা যায়নি: $e');
    }
  }

  Future<void> _openCamera() async {
    if (_isLoading || _exporting) return;

    await _videoController?.pause();
    await _audioController?.pause();

    final result = await Navigator.of(context).push<CameraResult>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    if (result == null || !mounted) return;

    await _loadVideo(result.path, from: result);
  }

  void _closeScreen() {
    if (_exporting) return;
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------
  // PLAY / FLIP / SPEED
  // ---------------------------------------------------------

  Future<void> _togglePlay() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }

    if (mounted) setState(() {});
  }

  void _toggleFlip() {
    setState(() => _flip = !_flip);
    _showMessage(_flip ? 'ভিডিও Flip করা হয়েছে' : 'Flip বন্ধ করা হয়েছে');
  }

  Future<void> _showSpeedDialog() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    final active = _speed == speed;
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(speed),
                      child: Container(
                        width: 82,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: active ? _pink : Colors.white10,
                          borderRadius: BorderRadius.circular(14),
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

    setState(() => _speed = selected);
    await c.setPlaybackSpeed(selected);
    await _audioController?.setPlaybackSpeed(selected);
    _showMessage('Speed ${selected}x করা হয়েছে');
  }

  // ---------------------------------------------------------
  // EFFECTS
  // ---------------------------------------------------------

  Future<void> _showEffectsDialog() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
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
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: kCreateEffects.map((e) {
                    final active = _effectId == e.id;
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(e.id),
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
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() => _effectId = selected);
  }

  // ---------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------

  Future<void> _addText() async {
    if (_videoController == null) return;

    if (_texts.length >= 5) {
      _showMessage('সর্বোচ্চ ৫টি লেখা যোগ করা যাবে।');
      return;
    }

    final result = await showTextEditor(context);
    if (result == null || result.text.isEmpty || !mounted) return;

    setState(() => _texts.add(result));
  }

  Future<void> _editText(TextOverlay t) async {
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

  // ---------------------------------------------------------
  // SOUND
  // ---------------------------------------------------------

  Future<void> _pickSound() async {
    final picked = await pickSoundFromDevice();
    if (picked == null || !mounted) return;

    _soundPath = picked.path;
    _soundName = picked.name;
    await _prepareAudio();

    final v = _videoController;
    final a = _audioController;
    if (v != null && a != null && v.value.isPlaying) {
      await a.seekTo(v.value.position);
      await a.play();
    }

    if (mounted) setState(() {});
  }

  Future<void> _removeSound() async {
    final a = _audioController;
    _audioController = null;
    await a?.dispose();

    _soundPath = null;
    _soundName = '';

    if (mounted) setState(() {});
  }

  Future<void> _showSoundSheet() async {
    if (_videoController == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sound',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(
                        Icons.library_music,
                        color: Colors.white,
                      ),
                      title: Text(
                        _soundPath == null
                            ? 'ফোন থেকে সাউন্ড যোগ করুন'
                            : 'অন্য সাউন্ড বাছুন',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        await _pickSound();
                        setSheet(() {});
                      },
                    ),
                    if (_soundPath != null) ...[
                      ListTile(
                        leading: const Icon(
                          Icons.music_note,
                          color: Colors.white70,
                        ),
                        title: Text(
                          _soundName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: _pink),
                          onPressed: () async {
                            await _removeSound();
                            setSheet(() {});
                          },
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.volume_down, color: Colors.white54),
                          Expanded(
                            child: Slider(
                              value: _soundVolume,
                              min: 0,
                              max: 1,
                              divisions: 10,
                              activeColor: _pink,
                              onChanged: (v) {
                                _soundVolume = v;
                                _audioController?.setVolume(v);
                                setSheet(() {});
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up, color: Colors.white54),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                    SwitchListTile(
                      activeColor: _pink,
                      title: const Text(
                        'মূল ভিডিওর শব্দ',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _hasOriginalAudio
                            ? 'বন্ধ করলে শুধু যোগ করা সাউন্ড থাকবে'
                            : 'এই ভিডিওতে মূল শব্দ নেই',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      value: _originalAudio && _hasOriginalAudio,
                      onChanged: _hasOriginalAudio
                          ? (v) {
                              _originalAudio = v;
                              _videoController?.setVolume(v ? 1.0 : 0.0);
                              setSheet(() {});
                            }
                          : null,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: _pink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------
  // SETTINGS
  // ---------------------------------------------------------

  Future<void> _openSettings() async {
    if (_exporting) return;
    await showCreateSettingsSheet(context);
  }

  // ---------------------------------------------------------
  // CONTINUE (EXPORT)
  // ---------------------------------------------------------

  CreateEdits _currentEdits() {
    return CreateEdits(
      effectId: _effectId,
      speed: _speed,
      flip: _flip,
      originalAudio: _originalAudio,
      hasOriginalAudio: _hasOriginalAudio,
      soundPath: _soundPath,
      soundName: _soundName,
      soundVolume: _soundVolume,
      texts: List<TextOverlay>.from(_texts),
    );
  }

  Future<void> _continueWithVideo() async {
    final video = _selectedVideo;
    final c = _videoController;

    if (video == null || c == null || _exporting) return;

    await c.pause();
    await _audioController?.pause();

    if (!mounted) return;
    setState(() => _exporting = true);

    final edits = _currentEdits();

    final out = await CreateExporter.export(
      inputPath: video.path,
      edits: edits,
      videoSize: c.value.size,
      exportWidth: CreateSettingsStore.current.exportWidth,
    );

    if (!mounted) return;
    setState(() => _exporting = false);

    if (out != null) {
      Navigator.of(context).pop(out);
      return;
    }

    // এডিট ছাড়া শুধু ছোট করা ব্যর্থ হলে মূল ভিডিও দিয়েই এগোই
    if (!edits.hasAnyEdit) {
      Navigator.of(context).pop(video.path);
      return;
    }

    final useOriginal = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text(
          'এডিট প্রয়োগ করা যায়নি',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'মূল ভিডিও (এডিট ছাড়া) দিয়ে এগোবেন?\n\n'
          '${CreateExporter.lastError}',
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('হ্যাঁ', style: TextStyle(color: _pink)),
          ),
        ],
      ),
    );

    if (useOriginal == true && mounted) {
      Navigator.of(context).pop(video.path);
    }
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
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  // ---------------------------------------------------------
  // PREVIEW
  // ---------------------------------------------------------

  Widget _buildPreview(VideoPlayerController c) {
    final cf = effectById(_effectId).colorFilter;

    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: LayoutBuilder(
          builder: (context, box) {
            Widget video = Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(_flip ? -1.0 : 1.0, 1.0, 1.0),
              child: VideoPlayer(c),
            );

            if (cf != null) {
              video = ColorFiltered(colorFilter: cf, child: video);
            }

            return GestureDetector(
              onTap: _togglePlay,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  video,
                  for (final t in _texts)
                    createTextLayer(
                      overlay: t,
                      width: box.maxWidth,
                      height: box.maxHeight,
                      onTap: () => _editText(t),
                      onDrag: (dx, dy) {
                        setState(() {
                          t.dx = (t.dx + dx).clamp(0.05, 0.95).toDouble();
                          t.dy = (t.dy + dy).clamp(0.05, 0.95).toDouble();
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = _videoController;
    final hasVideo = c != null && c.value.isInitialized;

    Widget body;

    if (hasVideo) {
      body = _buildPreview(c);
    } else {
      body = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF151515), Color(0xFF050505), Colors.black],
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
                  border: Border.all(color: Colors.white24, width: 1.5),
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
                style: TextStyle(color: Colors.white60, fontSize: 14),
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
            body,

            IgnorePointer(
              child: Container(
                height: 190,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
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
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

            // ---------------- TOP BAR ----------------
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleButton(icon: Icons.close, onTap: _closeScreen),
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
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),

            // ---------------- SIDE TOOLS ----------------
            if (hasVideo)
              Positioned(
                right: 14,
                top: MediaQuery.of(context).size.height * 0.32,
                child: Column(
                  children: [
                    _sideTool(
                      icon: Icons.flip,
                      label: 'Mirror',
                      onTap: _toggleFlip,
                      active: _flip,
                    ),
                    const SizedBox(height: 20),
                    _sideTool(
                      icon: Icons.speed,
                      label: '${_speed}x',
                      onTap: _showSpeedDialog,
                      active: _speed != 1.0,
                    ),
                  ],
                ),
              ),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: _pink)),

            // ---------------- BOTTOM ----------------
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _bottomTool(
                            icon: Icons.music_note,
                            label: 'Sound',
                            onTap: _showSoundSheet,
                            active: _soundPath != null || !_originalAudio,
                          ),
                          _bottomTool(
                            icon: Icons.auto_awesome,
                            label: 'Effects',
                            onTap: _showEffectsDialog,
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
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _galleryButton(),
                      GestureDetector(
                        onTap: hasVideo ? _togglePlay : _openCamera,
                        child: Container(
                          width: 82,
                          height: 82,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasVideo ? _pink : Colors.white,
                            ),
                            child: Icon(
                              hasVideo
                                  ? (c.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow)
                                  : Icons.camera_alt,
                              color: hasVideo ? Colors.white : Colors.black,
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
                              borderRadius: BorderRadius.circular(22),
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
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ---------------- EXPORTING ----------------
            if (_exporting)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _pink),
                          SizedBox(height: 18),
                          Text(
                            'ভিডিও প্রস্তুত হচ্ছে...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'কিছুক্ষণ অপেক্ষা করুন',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SMALL WIDGETS
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
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
    );
  }

  Widget _sideTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
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
              color: active ? _pink.withOpacity(0.25) : Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: active ? _pink : Colors.white24),
            ),
            child: Icon(
              icon,
              color: active ? _pink : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
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
        children: [
          Icon(icon, color: active ? _pink : Colors.white, size: 25),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? _pink : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickVideo(ImageSource.gallery),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white38),
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
              style: TextStyle(color: Colors.white, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
