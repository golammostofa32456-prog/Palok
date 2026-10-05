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
  static const Color _pink = Color(0xFFFF2D55);
  static const Color _cyan = Color(0xFF00E5FF);

  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset = 'palok_video_upload';

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

  // =========================================================
  // VIDEO PREVIEW
  // =========================================================

  Future<void> _initializePreview() async {
    final controller = VideoPlayerController.file(
      File(widget.filePath),
    );

    _previewController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  // =========================================================
  // PLAY / PAUSE
  // =========================================================

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

    if (mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // POST VIDEO
  // =========================================================

  Future<void> _postVideo() async {
    if (_uploading) {
      return;
    }

    final file = File(widget.filePath);

    if (!await file.exists()) {
      _showError('ভিডিও file পাওয়া যায়নি');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final caption = _captionController.text.trim();
    final filePath = widget.filePath;
    final username = widget.username;
    final userId = widget.userId;
    final firestore = widget.firestore;
    final onPosted = widget.onPosted;

    if (mounted) {
      setState(() {
        _uploading = true;
      });
    }

    // Stop preview while uploading.
    try {
      await _previewController?.pause();
    } catch (_) {}

    // =========================================================
    // CLOSE POST SCREEN
    // =========================================================

    if (mounted) {
      Navigator.of(context).pop();
    }

    // =========================================================
    // BACKGROUND UPLOAD
    // =========================================================

    try {
      final secureUrl = await _uploadToCloudinary(
        filePath,
      );

      if (secureUrl == null ||
          secureUrl.isEmpty) {
        throw Exception(
          'Video URL পাওয়া যায়নি',
        );
      }

      final hashtags = _extractHashtags(
        caption,
      );

      // =======================================================
      // FIRESTORE POST
      // =======================================================

      await firestore
          .collection('videos')
          .add({
        'videoUrl': secureUrl,
        'userId': userId,
        'username': username,
        'caption': caption,
        'hashtags': hashtags,
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'thumbnailUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // =======================================================
      // HOME FEED RELOAD
      // =======================================================

      await onPosted();

      // =======================================================
      // SUCCESS
      // =======================================================

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Upload failed: ${_cleanUploadError(e)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // CLOUDINARY UPLOAD
  // =========================================================

  Future<String?> _uploadToCloudinary(
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'ভিডিও file পাওয়া যায়নি',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudName/video/upload',
      ),
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
      ),
    );

    final streamedResponse = await request.send();

    final responseBody =
        await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      String message =
          'Cloudinary upload failed';

      try {
        final errorJson = jsonDecode(
          responseBody,
        );

        message =
            errorJson['error']?['message']
                    ?.toString() ??
                message;
      } catch (_) {}

      throw Exception(message);
    }

    final json = jsonDecode(responseBody);

    final secureUrl =
        (json['secure_url'] ?? '').toString();

    if (secureUrl.isEmpty) {
      throw Exception(
        'Video URL পাওয়া যায়নি',
      );
    }

    return secureUrl;
  }

  // =========================================================
  // HASHTAGS
  // =========================================================

  List<String> _extractHashtags(
    String text,
  ) {
    final matches = RegExp(
      r'#[A-Za-z0-9_\u0980-\u09FF]+',
    ).allMatches(text);

    return matches
        .map(
          (match) => match.group(0) ?? '',
        )
        .where(
          (tag) => tag.isNotEmpty,
        )
        .toList();
  }

  // =========================================================
  // ERROR CLEANER
  // =========================================================

  String _cleanUploadError(
    Object error,
  ) {
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
        .replaceFirst(
          'Exception: ',
          '',
        )
        .replaceFirst(
          'Error: ',
          '',
        );
  }

  // =========================================================
  // ERROR
  // =========================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // CLOSE
  // =========================================================

  void _closeScreen() {
    if (_uploading) {
      return;
    }

    Navigator.of(context).pop();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller = _previewController;

    final screenSize =
        MediaQuery.of(context).size;

    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    final isReady =
        controller != null &&
        controller.value.isInitialized;

    final isPlaying =
        isReady &&
        controller.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,

      body: Stack(
        fit: StackFit.expand,
        children: [
          // =====================================================
          // FULL SCREEN VIDEO
          // =====================================================

          GestureDetector(
            onTap: _togglePreview,

            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,

              child: isReady
                  ? FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: _pink,
                      ),
                    ),
            ),
          ),

          // =====================================================
          // DARK GRADIENT
          // =====================================================

          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [
                    0.0,
                    0.18,
                    0.60,
                    1.0,
                  ],
                  colors: [
                    Color(0x99000000),
                    Color(0x22000000),
                    Color(0x11000000),
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
          ),

          // =====================================================
          // TOP BAR
          // =====================================================

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                10,
                14,
                0,
              ),
              child: Row(
                children: [
                  _topButton(
                    icon: Icons.close,
                    onTap: _closeScreen,
                  ),

                  const Expanded(
                    child: Center(
                      child: Text(
                        'Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    child: Container(
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
                        _showDetails
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =====================================================
          // CENTER PLAY BUTTON
          // =====================================================

          if (isReady && !isPlaying)
            Center(
              child: GestureDetector(
                onTap: _togglePreview,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white30,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),

          // =====================================================
          // RIGHT SIDE TOOLS
          // =====================================================

          Positioned(
            right: 12,
            bottom: 215 + bottomInset,
            child: Column(
              children: [
                _sideAction(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: isPlaying
                      ? 'Pause'
                      : 'Play',
                  onTap: _togglePreview,
                ),

                const SizedBox(height: 18),

                _sideAction(
                  icon: Icons.edit_outlined,
                  label: 'Caption',
                  onTap: () {
                    setState(() {
                      _showDetails = true;
                    });
                  },
                ),

                const SizedBox(height: 18),

                _sideAction(
                  icon: Icons.tag_rounded,
                  label: 'Tags',
                  onTap: () {
                    setState(() {
                      _showDetails = true;
                    });
                  },
                ),
              ],
            ),
          ),

          // =====================================================
          // BOTTOM CONTENT
          // =====================================================

          Positioned(
            left: 14,
            right: 14,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(
                  milliseconds: 220,
                ),
                padding: EdgeInsets.only(
                  bottom: bottomInset,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =================================================
                    // USERNAME
                    // =================================================

                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                _pink,
                                _cyan,
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 11),

                        Expanded(
                          child: Text(
                            widget.username.startsWith('@')
                                ? widget.username
                                : '@${widget.username}',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 7,
                                ),
                              ],
                            ),
                          ),
                        ),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PALOK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // =================================================
                    // CAPTION
                    // =================================================

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showDetails = true;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        constraints:
                            const BoxConstraints(
                          maxHeight: 92,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius:
                              BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white12,
                          ),
                        ),
                        child: TextField(
                          controller:
                              _captionController,
                          enabled: !_uploading,
                          maxLines: 3,
                          maxLength: 2200,
                          textCapitalization:
                              TextCapitalization.sentences,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          decoration:
                              const InputDecoration(
                            hintText:
                                'Write a caption... #PALOK',
                            hintStyle: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.zero,
                            counterText: '',
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // DETAILS
                    // =================================================

                    if (_showDetails) ...[
                      const SizedBox(height: 10),

                      _compactOption(
                        icon:
                            Icons.visibility_outlined,
                        title:
                            'Who can watch',
                        value: 'Everyone',
                      ),

                      const SizedBox(height: 7),

                      _compactOption(
                        icon:
                            Icons.comment_outlined,
                        title:
                            'Comments',
                        value:
                            'Enabled',
                      ),
                    ],

                    const SizedBox(height: 12),

                    // =================================================
                    // POST BUTTON
                    // =================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _uploading
                                ? null
                                : _postVideo,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: _pink,
                          disabledBackgroundColor:
                              Colors.white24,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              15,
                            ),
                          ),
                        ),
                        child: _uploading
                            ? const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  SizedBox(
                                    width: 21,
                                    height: 21,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color:
                                          Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Posting...',
                                    style:
                                        TextStyle(
                                      fontSize: 16,
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
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // =================================================
                    // SMALL INFO
                    // =================================================

                    Center(
                      child: Text(
                        'Your video will appear on PALOK',
                        style: TextStyle(
                          color: Colors.white.withOpacity(
                            0.55,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),

                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ),

          // =====================================================
          // UPLOAD OVERLAY
          // =====================================================

          if (_uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 3,
                          color: _pink,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Posting to PALOK...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // TOP BUTTON
  // =========================================================

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    );
  }

  // =========================================================
  // SIDE ACTION
  // =========================================================

  Widget _sideAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
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
              size: 25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // COMPACT OPTION
  // =========================================================

  Widget _compactOption({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            color: Colors.white38,
            size: 19,
          ),
        ],
      ),
    );
  }
}
