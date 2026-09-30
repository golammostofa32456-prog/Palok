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

  final TextEditingController _captionController =
      TextEditingController();

  VideoPlayerController? _previewController;

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    final controller =
        VideoPlayerController.file(File(widget.filePath));

    _previewController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _postVideo() async {
    if (_uploading) return;

    final file = File(widget.filePath);

    if (!await file.exists()) {
      _showError('ভিডিও file পাওয়া যায়নি');
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
        ),
      );

      request.fields['upload_preset'] = _uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          widget.filePath,
        ),
      );

      final streamedResponse = await request.send();

      final responseBody =
          await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        String message = 'Cloudinary upload failed';

        try {
          final errorJson = jsonDecode(responseBody);

          message =
              errorJson['error']?['message']?.toString() ??
                  message;
        } catch (_) {}

        throw Exception(message);
      }

      final json = jsonDecode(responseBody);

      final secureUrl =
          (json['secure_url'] ?? '').toString();

      if (secureUrl.isEmpty) {
        throw Exception('Video URL পাওয়া যায়নি');
      }

      final caption = _captionController.text.trim();

      final hashtags = _extractHashtags(caption);

      await widget.firestore.collection('videos').add({
        'videoUrl': secureUrl,
        'userId': widget.userId,
        'username': widget.username,
        'caption': caption,
        'hashtags': hashtags,
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'thumbnailUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await widget.onPosted();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(
          'Upload failed: ${_cleanUploadError(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  List<String> _extractHashtags(String text) {
    final matches = RegExp(
      r'#[A-Za-z0-9_\u0980-\u09FF]+',
    ).allMatches(text);

    return matches
        .map((match) => match.group(0) ?? '')
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  String _cleanUploadError(Object error) {
    final text = error.toString();

    if (text.contains('Upload preset')) {
      return 'Cloudinary upload preset check করো';
    }

    if (text.contains('401')) {
      return 'Cloudinary authentication/configuration সমস্যা';
    }

    if (text.contains('413')) {
      return 'ভিডিও file অনেক বড়';
    }

    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Create Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        height: 360,
                        color: Colors.black,
                        child: _previewController != null &&
                                _previewController!
                                    .value
                                    .isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _previewController!
                                      .value
                                      .size
                                      .width,
                                  height: _previewController!
                                      .value
                                      .size
                                      .height,
                                  child: VideoPlayer(
                                    _previewController!,
                                  ),
                                ),
                              )
                            : const Center(
                                child:
                                    CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _captionController,
                      maxLines: 4,
                      enabled: !_uploading,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Write a caption... #PALOK',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withOpacity(0.07),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'ভিডিও সর্বোচ্চ ৩ মিনিট পর্যন্ত',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                18,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _uploading ? null : _postVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF2D55),
                    disabledBackgroundColor:
                        Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: _uploading
                      ? const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 21,
                              height: 21,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Post to PALOK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
}
