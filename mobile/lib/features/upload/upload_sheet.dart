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
  State<UploadSheet> createState() =>
      _UploadSheetState();
}

class _UploadSheetState
    extends State<UploadSheet> {
  static const Color _pink =
      Color(0xFFFF2D55);

  static const Color _cyan =
      Color(0xFF00E5FF);

  static const String _cloudName =
      'u0jufmrl';

  static const String _uploadPreset =
      'palok_video_upload';

  final TextEditingController
      _captionController =
      TextEditingController();

  VideoPlayerController?
      _previewController;

  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  // =========================================================
  // VIDEO PREVIEW
  // =========================================================

  Future<void> _initializePreview() async {
    final controller =
        VideoPlayerController.file(
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
    final controller =
        _previewController;

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

    final file =
        File(widget.filePath);

    if (!await file.exists()) {
      _showError(
        'ভিডিও file পাওয়া যায়নি',
      );
      return;
    }

    // Parent Scaffold-এর messenger আগে ধরে রাখছি।
    final messenger =
        ScaffoldMessenger.of(context);

    final caption =
        _captionController.text.trim();

    final filePath =
        widget.filePath;

    final username =
        widget.username;

    final userId =
        widget.userId;

    final firestore =
        widget.firestore;

    final onPosted =
        widget.onPosted;

    if (mounted) {
      setState(() {
        _uploading = true;
      });
    }

    // =========================================================
    // TikTok-style:
    // Post চাপার সঙ্গে সঙ্গে Post screen বন্ধ হবে।
    // Upload background-এ চলবে।
    // =========================================================

    if (mounted) {
      Navigator.of(context).pop();
    }

    // =========================================================
    // BACKGROUND UPLOAD
    // =========================================================

    try {
      final secureUrl =
          await _uploadToCloudinary(
        filePath,
      );

      if (secureUrl == null ||
          secureUrl.isEmpty) {
        throw Exception(
          'Video URL পাওয়া যায়নি',
        );
      }

      final hashtags =
          _extractHashtags(
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
        'createdAt':
            FieldValue.serverTimestamp(),
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
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Upload failed: ${_cleanUploadError(e)}',
          ),
          behavior:
              SnackBarBehavior.floating,
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
    final file =
        File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'ভিডিও file পাওয়া যায়নি',
      );
    }

    final request =
        http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudName/video/upload',
      ),
    );

    request.fields[
      'upload_preset'
    ] = _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
      ),
    );

    final streamedResponse =
        await request.send();

    final responseBody =
        await streamedResponse.stream
            .bytesToString();

    if (streamedResponse.statusCode <
            200 ||
        streamedResponse.statusCode >=
            300) {
      String message =
          'Cloudinary upload failed';

      try {
        final errorJson =
            jsonDecode(
          responseBody,
        );

        message =
            errorJson['error']?['message']
                    ?.toString() ??
                message;
      } catch (_) {}

      throw Exception(message);
    }

    final json =
        jsonDecode(responseBody);

    final secureUrl =
        (json['secure_url'] ?? '')
            .toString();

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
          (match) =>
              match.group(0) ?? '',
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
    final text =
        error.toString();

    if (text.contains(
      'Upload preset',
    )) {
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

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
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
    final controller =
        _previewController;

    final keyboard =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return Scaffold(
      backgroundColor:
          Colors.black,
      resizeToAvoidBottomInset:
          true,

      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // TOP BAR
            // =================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                10,
                14,
                8,
              ),
              child: Row(
                children: [
                  _topButton(
                    icon:
                        Icons.close,
                    onTap:
                        _closeScreen,
                  ),

                  const Expanded(
                    child: Center(
                      child: Text(
                        'Post',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 44,
                    height: 44,
                  ),
                ],
              ),
            ),

            // =================================================
            // CONTENT
            // =================================================

            Expanded(
              child:
                  SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,

                padding:
                    EdgeInsets.fromLTRB(
                  14,
                  6,
                  14,
                  keyboard + 24,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    // =================================================
                    // VIDEO PREVIEW
                    // =================================================

                    GestureDetector(
                      onTap:
                          _togglePreview,

                      child:
                          Container(
                        width:
                            double.infinity,

                        height:
                            MediaQuery.of(
                                  context,
                                ).size.height *
                                0.57,

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF151515,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                          border:
                              Border.all(
                            color:
                                Colors.white12,
                          ),
                        ),

                        clipBehavior:
                            Clip.antiAlias,

                        child:
                            Stack(
                          fit:
                              StackFit.expand,

                          children: [
                            if (controller !=
                                    null &&
                                controller
                                    .value
                                    .isInitialized)
                              FittedBox(
                                fit:
                                    BoxFit.contain,
                                child:
                                    SizedBox(
                                  width:
                                      controller
                                          .value
                                          .size
                                          .width,
                                  height:
                                      controller
                                          .value
                                          .size
                                          .height,
                                  child:
                                      VideoPlayer(
                                    controller,
                                  ),
                                ),
                              )
                            else
                              const Center(
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      _pink,
                                ),
                              ),

                            IgnorePointer(
                              child:
                                  Container(
                                decoration:
                                    const BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                    begin:
                                        Alignment.topCenter,
                                    end:
                                        Alignment.bottomCenter,
                                    colors: [
                                      Color(
                                        0x55000000,
                                      ),
                                      Colors
                                          .transparent,
                                      Color(
                                        0x66000000,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            if (controller !=
                                    null &&
                                controller
                                    .value
                                    .isInitialized &&
                                !controller
                                    .value
                                    .isPlaying)
                              Center(
                                child:
                                    Container(
                                  width:
                                      64,
                                  height:
                                      64,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.black
                                            .withOpacity(
                                      0.55,
                                    ),
                                    shape:
                                        BoxShape
                                            .circle,
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .play_arrow_rounded,
                                    color:
                                        Colors.white,
                                    size:
                                        40,
                                  ),
                                ),
                              ),

                            Positioned(
                              left:
                                  14,
                              bottom:
                                  14,
                              child:
                                  Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      10,
                                  vertical:
                                      6,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.black
                                          .withOpacity(
                                    0.45,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child:
                                    const Text(
                                  'PALOK',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        11,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =================================================
                    // USER
                    // =================================================

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              const BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            gradient:
                                LinearGradient(
                              colors: [
                                _pink,
                                _cyan,
                              ],
                            ),
                          ),
                          alignment:
                              Alignment.center,
                          child:
                              const Icon(
                            Icons.person,
                            color:
                                Colors.white,
                            size: 24,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                widget
                                        .username
                                        .startsWith(
                                      '@',
                                    )
                                    ? widget
                                        .username
                                    : '@${widget.username}',
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              const Text(
                                'Add a caption',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white54,
                                  fontSize:
                                      12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // =================================================
                    // CAPTION
                    // =================================================

                    Container(
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFF171717,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.white12,
                        ),
                      ),
                      child:
                          TextField(
                        controller:
                            _captionController,
                        enabled:
                            !_uploading,
                        maxLines:
                            5,
                        minLines:
                            3,
                        maxLength:
                            2200,
                        textCapitalization:
                            TextCapitalization
                                .sentences,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              15,
                          height:
                              1.35,
                        ),
                        decoration:
                            const InputDecoration(
                          hintText:
                              'Write a caption... #PALOK',
                          hintStyle:
                              TextStyle(
                            color:
                                Colors.white38,
                            fontSize:
                                15,
                          ),
                          border:
                              InputBorder
                                  .none,
                          contentPadding:
                              EdgeInsets
                                  .fromLTRB(
                            16,
                            15,
                            16,
                            12,
                          ),
                          counterStyle:
                              TextStyle(
                            color:
                                Colors.white30,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _optionRow(
                      icon:
                          Icons.tag_rounded,
                      title:
                          'Add hashtags',
                      subtitle:
                          'Caption-এর মধ্যে #hashtag ব্যবহার করুন',
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    _optionRow(
                      icon:
                          Icons.visibility_outlined,
                      title:
                          'Who can watch this video',
                      subtitle:
                          'Everyone',
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    _optionRow(
                      icon:
                          Icons.comment_outlined,
                      title:
                          'Allow comments',
                      subtitle:
                          'Comments are enabled',
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // POST BUTTON
            // =================================================

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                10,
                14,
                12,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    Colors.black,
                border:
                    Border(
                  top:
                      BorderSide(
                    color:
                        Colors.white12,
                  ),
                ),
              ),
              child:
                  SizedBox(
                width:
                    double.infinity,
                height:
                    54,
                child:
                    ElevatedButton(
                  onPressed:
                      _uploading
                          ? null
                          : _postVideo,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        _pink,
                    disabledBackgroundColor:
                        Colors.white12,
                    foregroundColor:
                        Colors.white,
                    elevation:
                        0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                  ),

                  child:
                      _uploading
                          ? const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                SizedBox(
                                  width:
                                      21,
                                  height:
                                      21,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.2,
                                    color:
                                        Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  width:
                                      10,
                                ),
                                Text(
                                  'Posting...',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Post to PALOK',
                              style:
                                  TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .w800,
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

  // =========================================================
  // TOP BUTTON
  // =========================================================

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child:
          Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(
          color:
              Colors.white10,
          shape:
              BoxShape.circle,
          border:
              Border.all(
            color:
                Colors.white12,
          ),
        ),
        child:
            Icon(
          icon,
          color:
              Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // =========================================================
  // OPTION ROW
  // =========================================================

  Widget _optionRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF121212),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color:
                  _pink.withOpacity(
                0.12,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              icon,
              color:
                  _pink,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        14,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white38,
                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right,
            color:
                Colors.white38,
            size: 22,
          ),
        ],
      ),
    );
  }
}
