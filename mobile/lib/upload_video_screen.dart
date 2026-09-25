import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  // ============================================================
  // PALOK / CLOUDINARY CONFIG
  // ============================================================

  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset = 'palok_video_upload';

  static const int _maxVideoBytes = 100 * 1024 * 1024;
  static const Duration _maxVideoDuration = Duration(minutes: 3);

  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // STATE
  // ============================================================

  File? _videoFile;
  VideoPlayerController? _videoController;

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagController =
      TextEditingController();

  bool _uploading = false;
  double _uploadProgress = 0.0;

  String _uploadStatus = '';
  String? _errorMessage;

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_uploading) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      final File file = File(pickedFile.path);

      final int fileSize = await file.length();

      if (fileSize > _maxVideoBytes) {
        _showError(
          'ভিডিও 100 MB-এর বেশি হতে পারবে না।',
        );
        return;
      }

      setState(() {
        _uploadStatus = 'ভিডিও পরীক্ষা করা হচ্ছে...';
      });

      final controller = VideoPlayerController.file(file);

      await controller.initialize();

      final Duration duration = controller.value.duration;

      if (duration > _maxVideoDuration) {
        await controller.dispose();

        _showError(
          'ভিডিও সর্বোচ্চ 3 মিনিটের হতে পারবে।',
        );
        return;
      }

      await _videoController?.dispose();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoFile = file;
        _videoController = controller;
        _uploadStatus = '';
        _uploadProgress = 0.0;
      });

      await controller.setLooping(true);
      await controller.play();
    } catch (e) {
      _showError(
        'ভিডিও নির্বাচন করা যায়নি। আবার চেষ্টা করুন।',
      );
    }
  }

  // ============================================================
  // REMOVE VIDEO
  // ============================================================

  Future<void> _removeVideo() async {
    if (_uploading) return;

    await _videoController?.dispose();

    if (!mounted) return;

    setState(() {
      _videoController = null;
      _videoFile = null;
      _uploadProgress = 0.0;
      _uploadStatus = '';
      _errorMessage = null;
    });
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>> _getUserProfile(
    String uid,
    User user,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      final data = snapshot.data();

      if (data == null) {
        return {
          'username':
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : 'PALOK User',
          'profileImage': user.photoURL ?? '',
        };
      }

      final String username =
          (data['username'] ??
                  data['displayName'] ??
                  user.displayName ??
                  'PALOK User')
              .toString()
              .trim();

      return {
        'username':
            username.isEmpty ? 'PALOK User' : username,
        'profileImage':
            (data['profileImage'] ?? user.photoURL ?? '')
                .toString(),
      };
    } catch (_) {
      return {
        'username':
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'PALOK User',
        'profileImage': user.photoURL ?? '',
      };
    }
  }

  // ============================================================
  // HASHTAGS
  // ============================================================

  List<String> _parseHashtags(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return <String>[];
    }

    final parts = text.split(RegExp(r'[\s,]+'));

    final List<String> hashtags = [];

    for (String part in parts) {
      part = part.trim();

      if (part.isEmpty) continue;

      if (!part.startsWith('#')) {
        part = '#$part';
      }

      if (!hashtags.contains(part)) {
        hashtags.add(part);
      }
    }

    return hashtags;
  }

  // ============================================================
  // CLOUDINARY UPLOAD
  // ============================================================

  Future<Map<String, dynamic>?> _uploadToCloudinary(
    File file,
  ) async {
    final Uri url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
    );

    final request = http.MultipartRequest(
      'POST',
      url,
    );

    request.fields['upload_preset'] = _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
      ),
    );

    setState(() {
      _uploadStatus = 'ভিডিও Upload হচ্ছে...';
      _uploadProgress = 0.0;
    });

    final streamedResponse = await request.send();

    final totalBytes = streamedResponse.contentLength;

    final List<int> responseBytes = [];

    int receivedBytes = 0;

    await for (final chunk in streamedResponse.stream) {
      responseBytes.addAll(chunk);

      receivedBytes += chunk.length;

      if (totalBytes != null && totalBytes > 0) {
        final progress =
            receivedBytes / totalBytes;

        if (mounted) {
          setState(() {
            _uploadProgress =
                progress.clamp(0.0, 1.0);
          });
        }
      }
    }

    final responseText =
        utf8.decode(responseBytes);

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed: '
        '${streamedResponse.statusCode}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(responseText)
            as Map<String, dynamic>;

    return data;
  }

  // ============================================================
  // UPLOAD VIDEO
  // ============================================================

  Future<void> _uploadVideo() async {
    if (_uploading) return;

    final user = _auth.currentUser;

    if (user == null) {
      _showError(
        'ভিডিও Upload করতে Login করতে হবে।',
      );
      return;
    }

    final File? file = _videoFile;

    if (file == null) {
      _showError(
        'প্রথমে একটি ভিডিও নির্বাচন করুন।',
      );
      return;
    }

    final caption =
        _captionController.text.trim();

    final hashtags =
        _parseHashtags(
          _hashtagController.text,
        );

    setState(() {
      _uploading = true;
      _errorMessage = null;
      _uploadProgress = 0.0;
      _uploadStatus = 'প্রস্তুত হচ্ছে...';
    });

    try {
      // --------------------------------------------------------
      // Re-check file size
      // --------------------------------------------------------

      final int fileSize = await file.length();

      if (fileSize > _maxVideoBytes) {
        throw Exception(
          'ভিডিও 100 MB-এর বেশি।',
        );
      }

      // --------------------------------------------------------
      // Re-check duration
      // --------------------------------------------------------

      final checkController =
          VideoPlayerController.file(file);

      await checkController.initialize();

      final duration =
          checkController.value.duration;

      await checkController.dispose();

      if (duration > _maxVideoDuration) {
        throw Exception(
          'ভিডিও সর্বোচ্চ 3 মিনিটের হতে পারবে।',
        );
      }

      // --------------------------------------------------------
      // User profile
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          _uploadStatus =
              'আপনার Profile তথ্য নেওয়া হচ্ছে...';
        });
      }

      final profile =
          await _getUserProfile(
        user.uid,
        user,
      );

      final String username =
          profile['username'].toString();

      // --------------------------------------------------------
      // Cloudinary
      // --------------------------------------------------------

      final cloudinaryData =
          await _uploadToCloudinary(file);

      if (cloudinaryData == null) {
        throw Exception(
          'ভিডিও Upload করা যায়নি।',
        );
      }

      final String videoUrl =
          (cloudinaryData['secure_url'] ?? '')
              .toString();

      if (videoUrl.isEmpty) {
        throw Exception(
          'Cloudinary থেকে ভিডিও URL পাওয়া যায়নি।',
        );
      }

      final String publicId =
          (cloudinaryData['public_id'] ?? '')
              .toString();

      final String assetId =
          (cloudinaryData['asset_id'] ?? '')
              .toString();

      // --------------------------------------------------------
      // Thumbnail
      // --------------------------------------------------------

      String thumbnailUrl = '';

      final String cloudinaryPublicId =
          publicId;

      if (cloudinaryPublicId.isNotEmpty) {
        final String thumbnailPublicId =
            cloudinaryPublicId
                .replaceFirst(
                  RegExp(r'\.[^.]+$'),
                  '',
                );

        thumbnailUrl =
            'https://res.cloudinary.com/'
            '$_cloudName/video/upload/'
            'so_0/'
            '$thumbnailPublicId.jpg';
      }

      // --------------------------------------------------------
      // Firestore
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          _uploadStatus =
              'PALOK-এ ভিডিও তথ্য সংরক্ষণ হচ্ছে...';
          _uploadProgress = 0.95;
        });
      }

      final videoDocument =
          _firestore.collection('videos').doc();

      await videoDocument.set({
        'ownerId': user.uid,
        'userId': user.uid,

        'username': username,

        'videoUrl': videoUrl,

        'cloudinaryPublicId':
            publicId,

        'cloudinaryAssetId':
            assetId,

        'thumbnailUrl':
            thumbnailUrl,

        'caption': caption,

        'hashtags': hashtags,

        'soundName': '',

        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus =
            'ভিডিও সফলভাবে PALOK-এ Upload হয়েছে!';
      });

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadStatus = '';
        _uploadProgress = 0.0;
      });

      _showError(
        _friendlyUploadError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _friendlyUploadError(Object error) {
    final message = error.toString();

    if (message.contains('100 MB')) {
      return 'ভিডিও 100 MB-এর বেশি হতে পারবে না।';
    }

    if (message.contains('3 মিনিট')) {
      return 'ভিডিও সর্বোচ্চ 3 মিনিটের হতে পারবে।';
    }

    if (message.contains('permission-denied')) {
      return 'ভিডিও সংরক্ষণ করার Permission পাওয়া যায়নি।';
    }

    if (message.contains('network')) {
      return 'Internet connection পরীক্ষা করে আবার চেষ্টা করুন।';
    }

    if (message.contains('Cloudinary')) {
      return 'ভিডিও Upload করা যায়নি। Cloudinary সেটিং পরীক্ষা করুন।';
    }

    return 'ভিডিও Upload করা যায়নি। আবার চেষ্টা করুন।';
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BACK
  // ============================================================

  Future<bool> _handleBack() async {
    if (_uploading) {
      return false;
    }

    return true;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Upload Video',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // ------------------------------------------------
                // VIDEO AREA
                // ------------------------------------------------

                _buildVideoArea(),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // CAPTION
                // ------------------------------------------------

                TextField(
                  controller: _captionController,
                  enabled: !_uploading,
                  maxLines: 4,
                  maxLength: 500,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      _inputDecoration(
                    label: 'Caption',
                    hint:
                        'আপনার ভিডিও সম্পর্কে কিছু লিখুন...',
                    icon: Icons.edit,
                  ),
                ),

                const SizedBox(height: 12),

                // ------------------------------------------------
                // HASHTAGS
                // ------------------------------------------------

                TextField(
                  controller: _hashtagController,
                  enabled: !_uploading,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      _inputDecoration(
                    label: 'Hashtags',
                    hint:
                        '#PALOK #Bangladesh #Creator',
                    icon: Icons.tag,
                  ),
                ),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // ERROR
                // ------------------------------------------------

                if (_errorMessage != null)
                  Container(
                    padding:
                        const EdgeInsets.all(12),
                    margin:
                        const EdgeInsets.only(
                      bottom: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(12),
                      color: Colors.red.withOpacity(
                        0.12,
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),

                // ------------------------------------------------
                // UPLOAD PROGRESS
                // ------------------------------------------------

                if (_uploading) ...[
                  Text(
                    _uploadStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 10),

                  LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 6,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],

                // ------------------------------------------------
                // UPLOAD BUTTON
                // ------------------------------------------------

                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _uploading ||
                                _videoFile == null
                            ? null
                            : _uploadVideo,
                    icon: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.cloud_upload,
                          ),
                    label: Text(
                      _uploading
                          ? 'Uploading...'
                          : 'Upload to PALOK',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ------------------------------------------------
                // INFO
                // ------------------------------------------------

                const Text(
                  'ভিডিও সীমা: সর্বোচ্চ 100 MB এবং 3 মিনিট',
                  textAlign: TextAlign.center,
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
    );
  }

  // ============================================================
  // VIDEO AREA UI
  // ============================================================

  Widget _buildVideoArea() {
    if (_videoController == null ||
        _videoFile == null) {
      return InkWell(
        onTap: _uploading
            ? null
            : _pickVideo,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          height: 430,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white24,
            ),
            color: const Color(0xFF111111),
          ),
          child: const Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: Colors.white,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'ভিডিও নির্বাচন করুন',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'সর্বোচ্চ 100 MB • 3 মিনিট',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller =
        _videoController!;

    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              if (!controller.value.isInitialized) {
                return;
              }

              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }

              setState(() {});
            },
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    controller.value.size.width,
                height:
                    controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),

          // ------------------------------------------------------
          // PLAY ICON
          // ------------------------------------------------------

          Center(
            child: ValueListenableBuilder<
                VideoPlayerValue>(
              valueListenable: controller,
              builder: (
                context,
                value,
                child,
              ) {
                if (value.isPlaying) {
                  return const SizedBox();
                }

                return Container(
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                );
              },
            ),
          ),

          // ------------------------------------------------------
          // REMOVE BUTTON
          // ------------------------------------------------------

          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed:
                    _uploading
                        ? null
                        : _removeVideo,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Colors.white70,
      ),
      hintStyle: const TextStyle(
        color: Colors.white38,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white70,
      ),
      filled: true,
      fillColor: const Color(0xFF111111),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.white12,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFFF2D55),
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.white12,
        ),
      ),
    );
  }
}
