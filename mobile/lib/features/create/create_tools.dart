import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kPalokPink = Color(0xFFFF2D55);
const Color kPalokCyan = Color(0xFF00E5FF);

// =====================================================================
// EFFECTS
// =====================================================================

class CreateEffect {
  final String id;
  final String label;
  final double saturation;
  final double r;
  final double g;
  final double b;
  final double brightness;

  const CreateEffect(
    this.id,
    this.label, {
    this.saturation = 1.0,
    this.r = 1.0,
    this.g = 1.0,
    this.b = 1.0,
    this.brightness = 0.0,
  });

  bool get isNone => id == 'none';

  /// 3x3 রঙের ম্যাট্রিক্স (row-major)।
  List<double> get mix {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final s = saturation;
    final rows = <List<double>>[
      [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)],
      [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)],
      [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s],
    ];
    final mult = <double>[r, g, b];
    final out = <double>[];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        out.add(rows[i][j] * mult[i]);
      }
    }
    return out;
  }

  /// প্রিভিউর জন্য।
  ColorFilter? get colorFilter {
    if (isNone) return null;
    final m = mix;
    final o = brightness * 255;
    return ColorFilter.matrix(<double>[
      m[0], m[1], m[2], 0, o,
      m[3], m[4], m[5], 0, o,
      m[6], m[7], m[8], 0, o,
      0, 0, 0, 1, 0,
    ]);
  }

  /// FFmpeg এর জন্য (প্রিভিউর সাথে প্রায় একই ফলাফল)।
  String? get ffmpegFilter {
    if (isNone) return null;
    final m = mix;
    String f(double v) => v.toStringAsFixed(4);
    final parts = <String>[
      'colorchannelmixer='
          'rr=${f(m[0])}:rg=${f(m[1])}:rb=${f(m[2])}:'
          'gr=${f(m[3])}:gg=${f(m[4])}:gb=${f(m[5])}:'
          'br=${f(m[6])}:bg=${f(m[7])}:bb=${f(m[8])}',
    ];
    if (brightness != 0) {
      parts.add('eq=brightness=${f(brightness)}');
    }
    return parts.join(',');
  }
}

const List<CreateEffect> kCreateEffects = <CreateEffect>[
  CreateEffect('none', 'None'),
  CreateEffect('dark', 'Dark', brightness: -0.12),
  CreateEffect('warm', 'Warm', saturation: 1.1, r: 1.08, b: 0.90),
  CreateEffect('cool', 'Cool', saturation: 1.05, r: 0.90, b: 1.10),
  CreateEffect('pink', 'Pink', saturation: 1.15, r: 1.10, g: 0.94, b: 1.04),
  CreateEffect('cyan', 'Cyan', saturation: 1.10, r: 0.88, g: 1.02, b: 1.10),
  CreateEffect('bw', 'B&W', saturation: 0.0),
  CreateEffect('vivid', 'Vivid', saturation: 1.5),
  CreateEffect('fade', 'Fade', saturation: 0.75, brightness: 0.06),
  CreateEffect('vintage', 'Vintage',
      saturation: 0.8, r: 1.08, b: 0.85, brightness: 0.03),
];

CreateEffect effectById(String id) {
  return kCreateEffects.firstWhere(
    (e) => e.id == id,
    orElse: () => kCreateEffects.first,
  );
}

// =====================================================================
// TEXT OVERLAY
// =====================================================================

class TextOverlay {
  final String id;
  String text;
  int colorValue;
  double size; // ৩৬০ পিক্সেল চওড়া ক্যানভাসের হিসাবে
  double dx; // ০..১ (ভিডিওর চওড়ার অনুপাত)
  double dy; // ০..১ (ভিডিওর উচ্চতার অনুপাত)

  TextOverlay({
    required this.id,
    required this.text,
    this.colorValue = 0xFFFFFFFF,
    this.size = 28,
    this.dx = 0.5,
    this.dy = 0.35,
  });

  Color get color => Color(colorValue);
}

TextStyle overlayTextStyle(TextOverlay t, double scale) {
  return TextStyle(
    color: t.color,
    fontSize: t.size * scale,
    fontWeight: FontWeight.w900,
    height: 1.15,
    shadows: [
      Shadow(
        color: Colors.black,
        blurRadius: 8 * scale,
        offset: Offset(2 * scale, 2 * scale),
      ),
    ],
  );
}

/// Stack এর ভেতরে লেখা বসানোর উইজেট (প্রিভিউর জন্য)।
Widget createTextLayer({
  required TextOverlay overlay,
  required double width,
  required double height,
  VoidCallback? onTap,
  void Function(double dxFraction, double dyFraction)? onDrag,
}) {
  final scale = width / 360.0;

  return Positioned(
    left: overlay.dx * width,
    top: overlay.dy * height,
    child: FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: onDrag == null
            ? null
            : (d) => onDrag(d.delta.dx / width, d.delta.dy / height),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * 0.84),
          child: Text(
            overlay.text,
            textAlign: TextAlign.center,
            style: overlayTextStyle(overlay, scale),
          ),
        ),
      ),
    ),
  );
}

// =====================================================================
// EDITS
// =====================================================================

class CreateEdits {
  String effectId;
  double speed;
  bool flip;
  bool originalAudio; // মূল অডিও চালু?
  bool hasOriginalAudio; // ভিডিওতে মূল অডিও আছে কি?
  String? soundPath;
  String soundName;
  double soundVolume;
  List<TextOverlay> texts;

  CreateEdits({
    this.effectId = 'none',
    this.speed = 1.0,
    this.flip = false,
    this.originalAudio = true,
    this.hasOriginalAudio = true,
    this.soundPath,
    this.soundName = '',
    this.soundVolume = 1.0,
    List<TextOverlay>? texts,
  }) : texts = texts ?? <TextOverlay>[];

  bool get hasAnyEdit =>
      effectId != 'none' ||
      speed != 1.0 ||
      flip ||
      !originalAudio ||
      soundPath != null ||
      texts.any((t) => t.text.trim().isNotEmpty);
}

class CameraResult {
  final String path;
  final CreateEdits edits;
  final bool hasOriginalAudio;

  const CameraResult({
    required this.path,
    required this.edits,
    this.hasOriginalAudio = true,
  });
}

// =====================================================================
// SETTINGS (Firestore: users/{uid}.createSettings)
// =====================================================================

class CreateSettings {
  int cameraQuality; // 0 = Medium, 1 = High, 2 = Very high
  int exportWidth; // 0 = Original, 720, 540
  int maxSeconds; // 15, 60, 180
  int defaultTimer; // 0, 3, 5, 10
  bool grid;

  CreateSettings({
    this.cameraQuality = 1,
    this.exportWidth = 720,
    this.maxSeconds = 180,
    this.defaultTimer = 0,
    this.grid = false,
  });

  CreateSettings copy() => CreateSettings(
        cameraQuality: cameraQuality,
        exportWidth: exportWidth,
        maxSeconds: maxSeconds,
        defaultTimer: defaultTimer,
        grid: grid,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cameraQuality': cameraQuality,
        'exportWidth': exportWidth,
        'maxSeconds': maxSeconds,
        'defaultTimer': defaultTimer,
        'grid': grid,
      };

  factory CreateSettings.fromMap(Map<dynamic, dynamic> m) {
    int pick(dynamic v, List<int> allowed, int fallback) {
      final n = v is num ? v.toInt() : fallback;
      return allowed.contains(n) ? n : fallback;
    }

    return CreateSettings(
      cameraQuality: pick(m['cameraQuality'], [0, 1, 2], 1),
      exportWidth: pick(m['exportWidth'], [0, 540, 720], 720),
      maxSeconds: pick(m['maxSeconds'], [15, 60, 180], 180),
      defaultTimer: pick(m['defaultTimer'], [0, 3, 5, 10], 0),
      grid: m['grid'] == true,
    );
  }
}

class CreateSettingsStore {
  static CreateSettings current = CreateSettings();
  static bool _loaded = false;

  static Future<CreateSettings> load() async {
    if (_loaded) return current;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return current;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 4));

      final raw = doc.data()?['createSettings'];
      if (raw is Map) {
        current = CreateSettings.fromMap(raw);
      }
      _loaded = true;
    } catch (e) {
      debugPrint('Create settings load error: $e');
    }

    return current;
  }

  static Future<void> save(CreateSettings s) async {
    current = s;
    _loaded = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        <String, dynamic>{'createSettings': s.toMap()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Create settings save error: $e');
    }
  }
}

Future<CreateSettings> showCreateSettingsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151515),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SettingsSheet(),
  );
  return CreateSettingsStore.current;
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late CreateSettings _s = CreateSettingsStore.current.copy();

  void _update(VoidCallback change) {
    setState(change);
    CreateSettingsStore.save(_s.copy());
  }

  Widget _group<T>(
    String title,
    String hint,
    Map<T, String> options,
    T value,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.entries.map((e) {
              final selected = e.key == value;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => onChanged(e.key),
                selectedColor: kPalokPink,
                backgroundColor: Colors.white10,
                labelStyle: const TextStyle(color: Colors.white),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            _group<int>(
              'ক্যামেরার মান',
              'পরের বার ক্যামেরা খুললে প্রযোজ্য',
              const {0: 'Medium', 1: 'High', 2: 'Very high'},
              _s.cameraQuality,
              (v) => _update(() => _s.cameraQuality = v),
            ),
            _group<int>(
              'আপলোডের মান',
              'ছোট মানে কম ডাটা ও দ্রুত আপলোড',
              const {0: 'Original', 720: '720p', 540: '540p'},
              _s.exportWidth,
              (v) => _update(() => _s.exportWidth = v),
            ),
            _group<int>(
              'সর্বোচ্চ রেকর্ডিং সময়',
              'সময় শেষ হলে নিজে থেকে থামবে',
              const {15: '15s', 60: '60s', 180: '3 min'},
              _s.maxSeconds,
              (v) => _update(() => _s.maxSeconds = v),
            ),
            _group<int>(
              'ডিফল্ট টাইমার',
              'প্রতিবার ক্যামেরা খুললে এটাই থাকবে',
              const {0: 'Off', 3: '3s', 5: '5s', 10: '10s'},
              _s.defaultTimer,
              (v) => _update(() => _s.defaultTimer = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kPalokPink,
              title: const Text(
                'গ্রিড লাইন',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'ক্যামেরায় রুল-অফ-থার্ডস গ্রিড',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: _s.grid,
              onChanged: (v) => _update(() => _s.grid = v),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: kPalokPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// TEXT EDITOR SHEET
// =====================================================================

/// নতুন/বদলানো লেখা ফেরত দেয়। ফেরত আসা text ফাঁকা হলে লেখাটি সরাতে হবে।
Future<TextOverlay?> showTextEditor(
  BuildContext context, {
  TextOverlay? initial,
}) {
  return showModalBottomSheet<TextOverlay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151515),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TextEditorSheet(initial: initial),
  );
}

class _TextEditorSheet extends StatefulWidget {
  final TextOverlay? initial;

  const _TextEditorSheet({this.initial});

  @override
  State<_TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial?.text ?? '');
  late int _color = widget.initial?.colorValue ?? 0xFFFFFFFF;
  late double _size = widget.initial?.size ?? 28;

  static const List<int> _colors = <int>[
    0xFFFFFFFF,
    0xFF000000,
    0xFFFF2D55,
    0xFF00E5FF,
    0xFFFFEB3B,
    0xFF69F0AE,
    0xFFFF9800,
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() {
    final text = _c.text.trim();
    FocusScope.of(context).unfocus();

    if (text.isEmpty) {
      final initial = widget.initial;
      if (initial == null) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop(TextOverlay(id: initial.id, text: ''));
      }
      return;
    }

    Navigator.of(context).pop(
      TextOverlay(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        colorValue: _color,
        size: _size,
        dx: widget.initial?.dx ?? 0.5,
        dy: widget.initial?.dy ?? 0.35,
      ),
    );
  }

  void _remove() {
    final initial = widget.initial;
    FocusScope.of(context).unfocus();
    if (initial == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop(TextOverlay(id: initial.id, text: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Add Text',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _c,
              autofocus: true,
              maxLength: 80,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ভিডিওতে Text লিখুন',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kPalokPink),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _colors.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? kPalokPink : Colors.white38,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('আকার', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _size,
                    min: 16,
                    max: 56,
                    activeColor: kPalokPink,
                    onChanged: (v) => setState(() => _size = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (widget.initial != null)
                  TextButton(
                    onPressed: _remove,
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _done,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: kPalokPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SOUND PICKER
// =====================================================================

class PickedSound {
  final String path;
  final String name;

  const PickedSound(this.path, this.name);
}

Future<PickedSound?> pickSoundFromDevice() async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) return null;

    return PickedSound(path, file.name);
  } catch (e) {
    debugPrint('Sound pick error: $e');
    return null;
  }
}

// =====================================================================
// EXPORT (FFmpeg)
// =====================================================================

class CreateExporter {
  static String lastError = '';

  static int _even(int v) {
    final x = v < 2 ? 2 : v;
    return x.isEven ? x : x + 1;
  }

  /// সফল হলে নতুন ফাইলের পাথ, ব্যর্থ হলে null (কারণ lastError এ)।
  static Future<String?> export({
    required String inputPath,
    required CreateEdits edits,
    required Size videoSize,
    required int exportWidth,
  }) async {
    lastError = '';

    final needs = edits.hasAnyEdit || exportWidth > 0;
    if (!needs) return inputPath;

    final inFile = File(inputPath);
    if (!await inFile.exists()) {
      lastError = 'ভিডিও ফাইল পাওয়া যায়নি';
      return null;
    }

    final dir = inFile.parent.path;
    final stamp = DateTime.now().millisecondsSinceEpoch;

    var outW = videoSize.width.round();
    var outH = videoSize.height.round();
    if (outW <= 0 || outH <= 0) {
      outW = 720;
      outH = 1280;
    }
    if (exportWidth > 0 && outW > exportWidth) {
      outH = (outH * exportWidth / outW).round();
      outW = exportWidth;
    }
    outW = _even(outW);
    outH = _even(outH);

    String? textPng;
    final activeTexts =
        edits.texts.where((t) => t.text.trim().isNotEmpty).toList();
    if (activeTexts.isNotEmpty) {
      textPng = await _renderTextLayer(
        activeTexts,
        outW,
        outH,
        '$dir/palok_text_$stamp.png',
      );
      if (textPng == null) {
        lastError = 'লেখা প্রস্তুত করা যায়নি';
        return null;
      }
    }

    final soundPath = edits.soundPath;
    if (soundPath != null && !await File(soundPath).exists()) {
      lastError = 'সাউন্ড ফাইল পাওয়া যায়নি';
      return null;
    }

    final output = '$dir/palok_edit_$stamp.mp4';

    final originalWanted = edits.originalAudio && edits.hasOriginalAudio;
    final audioModes = originalWanted ? <bool>[true, false] : <bool>[false];
    const encoders = <String>['libx264', 'h264_mediacodec'];

    for (final encoder in encoders) {
      for (final useOriginal in audioModes) {
        final args = _buildArgs(
          input: inputPath,
          output: output,
          edits: edits,
          textPng: textPng,
          useOriginalAudio: useOriginal,
          encoder: encoder,
          exportWidth: exportWidth,
        );

        final ok = await _run(args);
        if (ok) {
          final f = File(output);
          if (await f.exists() && await f.length() > 0) {
            if (textPng != null) {
              try {
                await File(textPng).delete();
              } catch (_) {}
            }
            return output;
          }
        }
      }
    }

    if (textPng != null) {
      try {
        await File(textPng).delete();
      } catch (_) {}
    }

    return null;
  }

  static List<String> _buildArgs({
    required String input,
    required String output,
    required CreateEdits edits,
    required String? textPng,
    required bool useOriginalAudio,
    required String encoder,
    required int exportWidth,
  }) {
    final args = <String>['-y', '-i', input];

    var next = 1;
    int? textIdx;
    int? soundIdx;

    if (textPng != null) {
      args.addAll(['-i', textPng]);
      textIdx = next++;
    }

    final soundPath = edits.soundPath;
    if (soundPath != null) {
      args.addAll(['-stream_loop', '-1', '-i', soundPath]);
      soundIdx = next++;
    }

    // ---------------- video ----------------
    final vf = <String>[];
    if (edits.flip) vf.add('hflip');
    if (exportWidth > 0) vf.add('scale=min($exportWidth\\,iw):-2');
    if (edits.speed != 1.0) {
      vf.add('setpts=${(1 / edits.speed).toStringAsFixed(4)}*PTS');
    }
    final fx = effectById(edits.effectId).ffmpegFilter;
    if (fx != null) vf.add(fx);
    if (vf.isEmpty) vf.add('null');

    final graph = <String>[];
    graph.add('[0:v]${vf.join(',')}[v0]');

    var vOut = '[v0]';
    if (textIdx != null) {
      graph.add('[v0][$textIdx:v]overlay=0:0[v1]');
      vOut = '[v1]';
    }

    // ---------------- audio ----------------
    final hasOriginal =
        useOriginalAudio && edits.originalAudio && edits.hasOriginalAudio;

    if (hasOriginal) {
      final af = <String>[];
      if (edits.speed != 1.0) {
        af.add('atempo=${edits.speed.toStringAsFixed(4)}');
      }
      if (af.isEmpty) af.add('anull');
      graph.add('[0:a]${af.join(',')}[a0]');
    }

    if (soundIdx != null) {
      graph.add(
        '[$soundIdx:a]volume=${edits.soundVolume.toStringAsFixed(2)}[a1]',
      );
    }

    String? aOut;
    if (hasOriginal && soundIdx != null) {
      graph.add(
        '[a0][a1]amix=inputs=2:duration=first:dropout_transition=0,'
        'volume=1.8,alimiter=limit=0.95[aout]',
      );
      aOut = '[aout]';
    } else if (hasOriginal) {
      aOut = '[a0]';
    } else if (soundIdx != null) {
      aOut = '[a1]';
    }

    args.addAll(['-filter_complex', graph.join(';'), '-map', vOut]);

    if (aOut != null) {
      args.addAll(['-map', aOut]);
    } else {
      args.add('-an');
    }

    // ---------------- encode ----------------
    if (encoder == 'libx264') {
      args.addAll(['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '27']);
    } else {
      args.addAll(['-c:v', 'h264_mediacodec', '-b:v', '4M']);
    }

    args.addAll(['-pix_fmt', 'yuv420p']);

    if (aOut != null) {
      args.addAll(['-c:a', 'aac', '-b:a', '128k']);
    }

    if (soundIdx != null) {
      args.add('-shortest');
    }

    args.addAll(['-movflags', '+faststart', output]);
    return args;
  }

  static Future<bool> _run(List<String> args) async {
    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final code = await session.getReturnCode();

      if (ReturnCode.isSuccess(code)) return true;

      final logs = await session.getAllLogsAsString() ?? '';
      final tail =
          logs.length > 260 ? logs.substring(logs.length - 260) : logs;
      lastError = tail.trim();
      debugPrint('FFmpeg failed: $lastError');
    } catch (e) {
      lastError = e.toString();
      debugPrint('FFmpeg exception: $e');
    }
    return false;
  }

  static Future<String?> _renderTextLayer(
    List<TextOverlay> texts,
    int w,
    int h,
    String path,
  ) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      );

      final scale = w / 360.0;

      for (final t in texts) {
        final painter = TextPainter(
          text: TextSpan(text: t.text, style: overlayTextStyle(t, scale)),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: w * 0.84);

        final offset = ui.Offset(
          t.dx * w - painter.width / 2,
          t.dy * h - painter.height / 2,
        );
        painter.paint(canvas, offset);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;

      await File(path).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return path;
    } catch (e) {
      debugPrint('Text layer error: $e');
      return null;
    }
  }
}
