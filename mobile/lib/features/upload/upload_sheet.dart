import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class UploadSheet extends StatefulWidget {
  final String filePath;
  final String username;
  final String userId;
  final FirebaseFirestore firestore;
  final Future<void> Function() onPosted;

  const UploadSheet({
    super.key,
    required this.filePath,
    required this.username,
    required this.userId,
    required this.firestore,
    required this.onPosted,
  });

  @override
  State<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<UploadSheet> {
  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset = 'palok_video_upload';

  // সর্বোচ্চ ভিডিও সাইজ: ১৫ MiB (15 × 1024 × 1024 bytes)
  static const int _maxVideoBytes = 15 * 1024 * 1024;

  final TextEditingController _captionController =
      TextEditingController();

  VideoPlayerController? _previewController;

  bool _uploading = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    final controller = VideoPlayerController.file(
      File(widget.filePath),
    );

    _previewController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final controller = _previewController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  List<String> _extractHashtags(String text) {
    return RegExp(r'#[A-Za-z0-9_\u0980-\u09FF]+')
        .allMatches(text)
        .map((match) => match.group(0) ?? '')
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  // আপলোডের আগে ফাইলের অস্তিত্ব ও আকার যাচাই।
  Future<int> _validateVideoFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('ভিডিও ফাইল পাওয়া যায়নি');
    }

    final size = await file.length();

    if (size <= 0) {
      throw Exception('ভিডিও ফাইলটি খালি');
    }

    if (size > _maxVideoBytes) {
      throw Exception(
        'ভিডিওর সর্বোচ্চ সাইজ ১৫ MB হতে পারবে। '
        'তোমার ভিডিওর সাইজ ${_formatSize(size)}।',
      );
    }

    return size;
  }

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<Map<String, String>> _uploadToCloudinary(
    String filePath,
  ) async {
    // আপলোড শুরুর ঠিক আগে আবার যাচাই।
    await _validateVideoFile(filePath);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudName/video/upload',
      ),
    );

    request.fields['upload_preset'] = _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw Exception(
        'Cloudinary থেকে সঠিক উত্তর পাওয়া যায়নি',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final dynamic errorData =
          decoded is Map ? decoded['error'] : null;

      final String? message = errorData is Map
          ? errorData['message']?.toString()
          : null;

      throw Exception(
        message ?? 'ভিডিও আপলোড ব্যর্থ হয়েছে',
      );
    }

    if (decoded is! Map) {
      throw Exception('ভিডিও URL পাওয়া যায়নি');
    }

    final videoUrl =
        (decoded['secure_url'] ?? '').toString();

    if (videoUrl.isEmpty) {
      throw Exception('ভিডিও URL পাওয়া যায়নি');
    }

    final thumbnailUrl = videoUrl
        .replaceFirst(
          '/video/upload/',
          '/video/upload/so_1,f_jpg/',
        )
        .replaceFirst(
          RegExp(
            r'\.(mp4|mov|webm|m4v)(\?.*)?$',
            caseSensitive: false,
          ),
          '.jpg',
        );

    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  Future<void> _postVideo() async {
    if (_uploading) return;

    final userId = widget.userId.trim();

    if (userId.isEmpty) {
      _showError('ব্যবহারকারীর ID পাওয়া যায়নি');
      return;
    }

    // আপলোড শুরু করার আগেই ফাইল পরীক্ষা।
    try {
      await _validateVideoFile(widget.filePath);
    } catch (error) {
      _showError(
        error.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _uploading = true);

    try {
      await _previewController?.pause();

      final uploaded =
          await _uploadToCloudinary(widget.filePath);

      final caption = _captionController.text.trim();

      final userSnapshot = await widget.firestore
          .collection('users')
          .doc(userId)
          .get();

      final userData =
          userSnapshot.data() ?? <String, dynamic>{};

      final username = widget.username.trim().isNotEmpty
          ? widget.username
              .trim()
              .replaceFirst(RegExp(r'^@'), '')
          : (userData['username'] ?? 'PALOK User').toString();

      final profileImageUrl = (
        userData['profileImageUrl'] ??
        userData['profileImage'] ??
        userData['photoURL'] ??
        userData['photoUrl'] ??
        ''
      ).toString();

      await widget.firestore.collection('videos').add({
        'videoUrl': uploaded['videoUrl'],
        'thumbnailUrl': uploaded['thumbnailUrl'],
        'ownerId': userId,
        'userId': userId,
        'username': username,
        'profileImageUrl': profileImageUrl,
        'caption': caption,
        'hashtags': _extractHashtags(caption),
        'soundName': '',
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await widget.onPosted();
    } catch (error) {
      if (!mounted) return;

      setState(() => _uploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'আপলোড ব্যর্থ: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _previewController;
    final ready = controller?.value.isInitialized ?? false;
    final playing = ready && controller!.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _togglePreview,
            child: ColoredBox(
              color: Colors.black,
              child: ready
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: controller!.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF2D55),
                      ),
                    ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _uploading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Post to PALOK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _uploading
                            ? null
                            : () {
                                setState(() {
                                  _showDetails = !_showDetails;
                                });
                              },
                        icon: Icon(
                          _showDetails
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (ready && !playing)
                  IconButton(
                    onPressed: _togglePreview,
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16, 8, 16, 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${widget.username.replaceFirst(RegExp(r'^@'), '')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _captionController,
                        enabled: !_uploading,
                        maxLines: 3,
                        maxLength: 2200,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write a caption... #PALOK',
                          hintStyle: const TextStyle(
                            color: Colors.white60,
                          ),
                          filled: true,
                          fillColor: Colors.black54,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_showDetails)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'সর্বোচ্চ ভিডিও সাইজ ১৫ MB। '
                            'পোস্টটি পাবলিক ভিডিও হিসেবে সংরক্ষিত হবে।',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _uploading ? null : _postVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFFF2D55),
                            foregroundColor: Colors.white,
                          ),
                          child: _uploading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Post to PALOK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
