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
    } catch (_) {}
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();

    super.dispose();
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

    // -------------------------------------------------------
    // এই context এখনো valid থাকা অবস্থায়
    // parent Scaffold-এর messenger নিয়ে রাখছি।
    // -------------------------------------------------------

    final messenger =
        ScaffoldMessenger.of(context);

    // -------------------------------------------------------
    // Caption আগে নিয়ে রাখছি।
    // Sheet বন্ধ হয়ে যাওয়ার পরও
    // background upload এগুলো ব্যবহার করবে।
    // -------------------------------------------------------

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

    // -------------------------------------------------------
    // UI-তে uploading state দেখাও
    // -------------------------------------------------------

    if (mounted) {
      setState(() {
        _uploading = true;
      });
    }

    // -------------------------------------------------------
    // TikTok-style behavior:
    //
    // Post চাপার সঙ্গে সঙ্গে Create Video sheet বন্ধ।
    // Upload এরপর background-এ চলবে।
    // -------------------------------------------------------

    if (mounted) {
      Navigator.of(context).pop();
    }

    // -------------------------------------------------------
    // এখন আসল upload শুরু।
    //
    // Sheet বন্ধ হয়ে গেলেও এই async operation চলতে থাকবে।
    // -------------------------------------------------------

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

      // -----------------------------------------------------
      // Caption + hashtags
      // -----------------------------------------------------

      final hashtags =
          _extractHashtags(caption);

      // -----------------------------------------------------
      // Firestore-এ video post তৈরি
      // -----------------------------------------------------

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

      // -----------------------------------------------------
      // Home screen feed reload
      // -----------------------------------------------------

      await onPosted();

      // -----------------------------------------------------
      // Upload successful message
      // -----------------------------------------------------

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
      // -----------------------------------------------------
      // Sheet ইতিমধ্যে বন্ধ।
      // তাই এখানে context ব্যবহার না করে
      // একই parent messenger ব্যবহার করছি।
      // -----------------------------------------------------

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

    // -------------------------------------------------------
    // HTTP error
    // -------------------------------------------------------

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

    // -------------------------------------------------------
    // JSON
    // -------------------------------------------------------

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
  // ERROR MESSAGE
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
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bottomInset =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return AnimatedPadding(
      duration:
          const Duration(
        milliseconds: 180,
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: Container(
        height:
            MediaQuery.of(context)
                    .size
                    .height *
                0.82,
        decoration:
            const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),

            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'Create Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  18,
                  0,
                  18,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    // =================================================
                    // VIDEO PREVIEW
                    // =================================================

                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                      child: Container(
                        width:
                            double.infinity,
                        height: 360,
                        color:
                            Colors.black,
                        child: _previewController !=
                                    null &&
                                _previewController!
                                    .value
                                    .isInitialized
                            ? FittedBox(
                                fit:
                                    BoxFit.cover,
                                child:
                                    SizedBox(
                                  width:
                                      _previewController!
                                          .value
                                          .size
                                          .width,
                                  height:
                                      _previewController!
                                          .value
                                          .size
                                          .height,
                                  child:
                                      VideoPlayer(
                                    _previewController!,
                                  ),
                                ),
                              )
                            : const Center(
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // =================================================
                    // CAPTION
                    // =================================================

                    TextField(
                      controller:
                          _captionController,
                      maxLines: 4,
                      enabled:
                          !_uploading,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            'Write a caption... #PALOK',
                        hintStyle:
                            const TextStyle(
                          color:
                              Colors.white38,
                        ),
                        filled: true,
                        fillColor:
                            Colors.white
                                .withOpacity(
                          0.07,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const Text(
                      'ভিডিও সর্বোচ্চ ৩ মিনিট পর্যন্ত',
                      style:
                          TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // POST BUTTON
            // =================================================

            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                18,
                8,
                18,
                18,
              ),
              child: SizedBox(
                width:
                    double.infinity,
                height: 52,
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
                        const Color(
                      0xFFFF2D55,
                    ),
                    disabledBackgroundColor:
                        Colors.white12,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
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
                                strokeWidth:
                                    2.2,
                                color:
                                    Colors.white,
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              'Posting...',
                              style:
                                  TextStyle(
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
                            fontSize: 16,
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
}
