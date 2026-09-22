import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({
    super.key,
  });

  @override
  State<UploadVideoScreen> createState() =>
      _UploadVideoScreenState();
}

class _UploadVideoScreenState
    extends State<UploadVideoScreen> {
  // ============================================================
  // PALOK / CLOUDINARY CONFIG
  // ============================================================

  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset =
      'palok_video_upload';

  static const int _maxVideoBytes =
      100 * 1024 * 1024;

  static const Duration _maxVideoDuration =
      Duration(minutes: 3);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final ImagePicker _picker =
      ImagePicker();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagController =
      TextEditingController();

  // ============================================================
  // VIDEO
  // ============================================================

  File? _videoFile;

  VideoPlayerController? _videoController;

  Duration _videoDuration =
      Duration.zero;

  // ============================================================
  // UPLOAD STATE
  // ============================================================

  bool _uploading = false;

  double _uploadProgress = 0.0;

  String _uploadStatus = '';

  // ============================================================
  // COLORS
  // ============================================================

  static const Color _pink =
      Color(0xFFFF2D55);

  static const Color _cyan =
      Color(0xFF00E5FF);

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();

    _videoController?.dispose();

    super.dispose();
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_uploading) {
      return;
    }

    try {
      final XFile? pickedFile =
          await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      final File file =
          File(pickedFile.path);

      // ----------------------------------------------------------
      // FILE SIZE
      // ----------------------------------------------------------

      final int fileSize =
          await file.length();

      if (fileSize > _maxVideoBytes) {
        _showMessage(
          'ভিডিও 100 MB বা তার কম হতে হবে।',
        );
        return;
      }

      // ----------------------------------------------------------
      // OLD CONTROLLER
      // ----------------------------------------------------------

      await _videoController?.dispose();

      _videoController = null;

      // ----------------------------------------------------------
      // NEW CONTROLLER
      // ----------------------------------------------------------

      final VideoPlayerController controller =
          VideoPlayerController.file(file);

      await controller.initialize();

      final Duration duration =
          controller.value.duration;

      // ----------------------------------------------------------
      // DURATION
      // ----------------------------------------------------------

      if (duration > _maxVideoDuration) {
        await controller.dispose();

        _showMessage(
          'ভিডিও সর্বোচ্চ 3 মিনিটের হতে হবে।',
        );

        return;
      }

      // ----------------------------------------------------------
      // LOOP
      // ----------------------------------------------------------

      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoFile = file;
        _videoController = controller;
        _videoDuration = duration;
      });

      // ----------------------------------------------------------
      // PREVIEW PLAY
      // ----------------------------------------------------------

      await controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Pick video error: $e',
      );

      _showMessage(
        'ভিডিও নির্বাচন করা যায়নি। আবার চেষ্টা করুন।',
      );
    }
  }

  // ============================================================
  // CLOUDINARY UPLOAD
  // ============================================================

  Future<Map<String, dynamic>> _cloudinaryUpload(
    File file,
  ) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/video/upload',
    );

    final String boundary =
        '----PALOK'
        '${DateTime.now().microsecondsSinceEpoch}';

    final int fileLength =
        await file.length();

    // ----------------------------------------------------------
    // FILE EXTENSION
    // ----------------------------------------------------------

    String extension = 'mp4';

    final String originalPath =
        file.path.toLowerCase();

    if (originalPath.endsWith('.mov')) {
      extension = 'mov';
    } else if (originalPath.endsWith('.m4v')) {
      extension = 'm4v';
    } else if (originalPath.endsWith('.webm')) {
      extension = 'webm';
    }

    final String fileName =
        'palok_${DateTime.now().millisecondsSinceEpoch}'
        '.$extension';

    // ----------------------------------------------------------
    // CONTENT TYPE
    // ----------------------------------------------------------

    String contentType =
        'video/mp4';

    if (extension == 'mov') {
      contentType = 'video/quicktime';
    } else if (extension == 'webm') {
      contentType = 'video/webm';
    }

    // ----------------------------------------------------------
    // MULTIPART PREFIX
    // ----------------------------------------------------------

    final String prefix =
        '--$boundary\r\n'
        'Content-Disposition: form-data; '
        'name="upload_preset"\r\n\r\n'
        '$_uploadPreset\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; '
        'name="file"; filename="$fileName"\r\n'
        'Content-Type: $contentType\r\n\r\n';

    // ----------------------------------------------------------
    // MULTIPART SUFFIX
    // ----------------------------------------------------------

    final String suffix =
        '\r\n--$boundary--\r\n';

    final List<int> prefixBytes =
        utf8.encode(prefix);

    final List<int> suffixBytes =
        utf8.encode(suffix);

    final int total =
        prefixBytes.length +
        fileLength +
        suffixBytes.length;

    int sent = 0;

    // ----------------------------------------------------------
    // REQUEST
    // ----------------------------------------------------------

    final http.StreamedRequest request =
        http.StreamedRequest(
      'POST',
      uri,
    );

    request.headers['Content-Type'] =
        'multipart/form-data; boundary=$boundary';

    request.headers['Accept'] =
        'application/json';

    request.contentLength = total;

    // ----------------------------------------------------------
    // SEND
    // ----------------------------------------------------------

    final Future<http.StreamedResponse>
        responseFuture =
        request.send();

    // ----------------------------------------------------------
    // PREFIX
    // ----------------------------------------------------------

    request.sink.add(prefixBytes);

    sent += prefixBytes.length;

    _setUploadProgress(
      sent / total,
      'ভিডিও আপলোড হচ্ছে...',
    );

    // ----------------------------------------------------------
    // FILE STREAM
    // ----------------------------------------------------------

    await for (
      final List<int> chunk
      in file.openRead()
    ) {
      request.sink.add(chunk);

      sent += chunk.length;

      _setUploadProgress(
        sent / total,
        'ভিডিও আপলোড হচ্ছে...',
      );
    }

    // ----------------------------------------------------------
    // SUFFIX
    // ----------------------------------------------------------

    request.sink.add(suffixBytes);

    sent += suffixBytes.length;

    _setUploadProgress(
      1.0,
      'ভিডিও প্রসেস হচ্ছে...',
    );

    // ----------------------------------------------------------
    // CLOSE
    // ----------------------------------------------------------

    await request.sink.close();

    // ----------------------------------------------------------
    // RESPONSE
    // ----------------------------------------------------------

    final http.StreamedResponse response =
        await responseFuture;

    final String body =
        await response.stream.bytesToString();

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'Cloudinary error '
          '(${response.statusCode})';

      try {
        final dynamic decoded =
            jsonDecode(body);

        if (decoded is Map<String, dynamic>) {
          final dynamic error =
              decoded['error'];

          if (error is Map) {
            message =
                (error['message'] ?? message)
                    .toString();
          }
        }
      } catch (_) {}

      throw Exception(message);
    }

    // ----------------------------------------------------------
    // JSON
    // ----------------------------------------------------------

    final dynamic decoded =
        jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Cloudinary response সঠিক নয়।',
      );
    }

    return decoded;
  }

  // ============================================================
  // UPLOAD PROGRESS
  // ============================================================

  void _setUploadProgress(
    double value,
    String status,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _uploadProgress =
          value.clamp(0.0, 1.0);

      _uploadStatus = status;
    });
  }

  // ============================================================
  // LOAD USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>>
      _getUserProfile(
    User user,
  ) async {
    try {
      final DocumentSnapshot<
          Map<String, dynamic>> snapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? data =
          snapshot.data();

      if (data != null) {
        return data;
      }
    } catch (e) {
      debugPrint(
        'User profile error: $e',
      );
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // GET USERNAME
  // ============================================================

  Future<String> _getUsername(
    User user,
  ) async {
    final Map<String, dynamic> profile =
        await _getUserProfile(user);

    final String username =
        (profile['username'] ?? '')
            .toString()
            .trim();

    if (username.isNotEmpty) {
      return username.startsWith('@')
          ? username
          : '@$username';
    }

    final String displayName =
        (profile['displayName'] ??
                profile['name'] ??
                user.displayName ??
                '')
            .toString()
            .trim();

    if (displayName.isNotEmpty) {
      return '@$displayName';
    }

    if (user.email != null &&
        user.email!.contains('@')) {
      return '@${user.email!.split('@').first}';
    }

    return '@palok_user';
  }

  // ============================================================
  // GET PROFILE IMAGE
  // ============================================================

  Future<String> _getProfileImage(
    User user,
  ) async {
    final Map<String, dynamic> profile =
        await _getUserProfile(user);

    final String profileImage =
        (profile['profileImage'] ?? '')
            .toString()
            .trim();

    if (profileImage.isNotEmpty) {
      return profileImage;
    }

    return user.photoURL ?? '';
  }

  // ============================================================
  // HASHTAGS
  // ============================================================

  List<String> _getHashtags() {
    final String text =
        _hashtagController.text.trim();

    if (text.isEmpty) {
      return <String>[];
    }

    final List<String> rawTags =
        text
            .split(RegExp(r'[\s,#]+'))
            .where(
              (String tag) =>
                  tag.trim().isNotEmpty,
            )
            .map(
              (String tag) =>
                  tag.trim(),
            )
            .toList();

    final List<String> hashtags =
        <String>[];

    for (final String rawTag in rawTags) {
      String tag = rawTag;

      if (!tag.startsWith('#')) {
        tag = '#$tag';
      }

      if (!hashtags.contains(tag)) {
        hashtags.add(tag);
      }

      // Avoid an excessive number of hashtags.
      if (hashtags.length >= 20) {
        break;
      }
    }

    return hashtags;
  }

  // ============================================================
  // UPLOAD VIDEO
  // ============================================================

  Future<void> _uploadVideo() async {
    // ----------------------------------------------------------
    // VIDEO CHECK
    // ----------------------------------------------------------

    if (_videoFile == null ||
        _videoController == null) {
      _showMessage(
        'প্রথমে একটি ভিডিও নির্বাচন করুন।',
      );

      return;
    }

    // ----------------------------------------------------------
    // UPLOAD CHECK
    // ----------------------------------------------------------

    if (_uploading) {
      return;
    }

    // ----------------------------------------------------------
    // AUTH CHECK
    // ----------------------------------------------------------

    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'আগে Login করুন।',
      );

      return;
    }

    // ----------------------------------------------------------
    // FILE SIZE CHECK AGAIN
    // ----------------------------------------------------------

    final int fileSize =
        await _videoFile!.length();

    if (fileSize > _maxVideoBytes) {
      _showMessage(
        'ভিডিও 100 MB বা তার কম হতে হবে।',
      );

      return;
    }

    // ----------------------------------------------------------
    // DURATION CHECK
    // ----------------------------------------------------------

    final Duration duration =
        _videoController!.value.duration;

    if (duration <= Duration.zero) {
      _showMessage(
        'ভিডিওর duration পাওয়া যায়নি।',
      );

      return;
    }

    if (duration > _maxVideoDuration) {
      _showMessage(
        'ভিডিও সর্বোচ্চ 3 মিনিটের হতে হবে।',
      );

      return;
    }

    // ----------------------------------------------------------
    // CAPTION
    // ----------------------------------------------------------

    final String caption =
        _captionController.text.trim();

    // ----------------------------------------------------------
    // HASHTAGS
    // ----------------------------------------------------------

    final List<String> hashtags =
        _getHashtags();

    try {
      // --------------------------------------------------------
      // START
      // --------------------------------------------------------

      setState(() {
        _uploading = true;
        _uploadProgress = 0.0;
        _uploadStatus =
            'ভিডিও প্রস্তুত করা হচ্ছে...';
      });

      // --------------------------------------------------------
      // PAUSE
      // --------------------------------------------------------

      await _videoController?.pause();

      // --------------------------------------------------------
      // USER PROFILE
      // --------------------------------------------------------

      final Map<String, dynamic> profile =
          await _getUserProfile(user);

      final String username =
          await _getUsername(user);

      final String profileImage =
          await _getProfileImage(user);

      // --------------------------------------------------------
      // CLOUDINARY
      // --------------------------------------------------------

      final Map<String, dynamic> cloudinaryData =
          await _cloudinaryUpload(
        _videoFile!,
      );

      // --------------------------------------------------------
      // VIDEO URL
      // --------------------------------------------------------

      final String videoUrl =
          (cloudinaryData['secure_url'] ?? '')
              .toString()
              .trim();

      if (videoUrl.isEmpty) {
        throw Exception(
          'Cloudinary video URL পাওয়া যায়নি।',
        );
      }

      // --------------------------------------------------------
      // CLOUDINARY IDS
      // --------------------------------------------------------

      final String publicId =
          (cloudinaryData['public_id'] ?? '')
              .toString()
              .trim();

      final String assetId =
          (cloudinaryData['asset_id'] ?? '')
              .toString()
              .trim();

      final String resourceType =
          (cloudinaryData['resource_type'] ?? 'video')
              .toString();

      // --------------------------------------------------------
      // FIRESTORE STATUS
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          _uploadStatus =
              'PALOK-এ পোস্ট সংরক্ষণ হচ্ছে...';
        });
      }

      // --------------------------------------------------------
      // VIDEO DOCUMENT
      // --------------------------------------------------------

      final DocumentReference<
          Map<String, dynamic>> videoRef =
          _firestore
              .collection('videos')
              .doc();

      // --------------------------------------------------------
      // IMPORTANT
      //
      // Canonical owner field = userId
      //
      // HomeScreen reads userId.
      // So ownerId is NOT used here.
      // --------------------------------------------------------

      await videoRef.set(
        <String, dynamic>{
          // ----------------------------------------------------
          // OWNER
          // ----------------------------------------------------

          'userId': user.uid,

          // ----------------------------------------------------
          // CREATOR INFO
          // ----------------------------------------------------

          'username': username,

          'profileImage': profileImage,

          // ----------------------------------------------------
          // VIDEO
          // ----------------------------------------------------

          'videoUrl': videoUrl,

          // Don't use the MP4 URL as an image thumbnail.
          // Home can safely fall back to video.
          'thumbnailUrl': '',

          // ----------------------------------------------------
          // CLOUDINARY
          // ----------------------------------------------------

          'cloudinaryPublicId': publicId,

          'cloudinaryAssetId': assetId,

          'resourceType': resourceType,

          // ----------------------------------------------------
          // CONTENT
          // ----------------------------------------------------

          'caption': caption,

          'hashtags': hashtags,

          'soundName': 'Original sound',

          // ----------------------------------------------------
          // COUNTERS
          // ----------------------------------------------------

          'likeCount': 0,

          'commentCount': 0,

          'saveCount': 0,

          'shareCount': 0,

          // ----------------------------------------------------
          // CREATED
          // ----------------------------------------------------

          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      // --------------------------------------------------------
      // ENSURE USER DOCUMENT
      // --------------------------------------------------------

      final DocumentReference<
          Map<String, dynamic>> userRef =
          _firestore
              .collection('users')
              .doc(user.uid);

      final Map<String, dynamic>
          userUpdate =
          <String, dynamic>{
        'uid': user.uid,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      // Only add missing basic fields.
      if (!profile.containsKey('followersCount')) {
        userUpdate['followersCount'] = 0;
      }

      if (!profile.containsKey('followingCount')) {
        userUpdate['followingCount'] = 0;
      }

      if (!profile.containsKey('email') &&
          user.email != null) {
        userUpdate['email'] =
            user.email;
      }

      if (!profile.containsKey('profileImage') &&
          profileImage.isNotEmpty) {
        userUpdate['profileImage'] =
            profileImage;
      }

      await userRef.set(
        userUpdate,
        SetOptions(merge: true),
      );

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      if (!mounted) {
        return;
      }

      setState(() {
        _uploading = false;
        _uploadProgress = 1.0;
        _uploadStatus = '';
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉',
          ),
          duration:
              Duration(seconds: 2),
        ),
      );

      // --------------------------------------------------------
      // RETURN HOME
      // --------------------------------------------------------

      await Future.delayed(
        const Duration(
          milliseconds: 800,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      // --------------------------------------------------------
      // ERROR
      // --------------------------------------------------------

      debugPrint(
        'Video upload error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploading = false;
        _uploadStatus = '';
      });

      _showMessage(
        'ভিডিও পোস্ট করা যায়নি:\n'
        '${e.toString().replaceFirst(
          'Exception: ',
          '',
        )}',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
        ),
      );
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String _formatDuration(
    Duration duration,
  ) {
    final int minutes =
        duration.inMinutes;

    final int seconds =
        duration.inSeconds % 60;

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  Widget _buildPreview() {
    final VideoPlayerController? controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: 430,

        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius:
              BorderRadius.circular(18),

          border: Border.all(
            color: Colors.white12,
          ),
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 82,
              height: 82,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  colors: [
                    _pink,
                    _cyan,
                  ],
                ),
              ),

              child: const Icon(
                Icons.video_library_outlined,
                color: Colors.white,
                size: 42,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Select a video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Maximum 100 MB • 3 minutes',
              style: TextStyle(
                color: Colors.white
                    .withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final Duration duration =
        controller.value.duration;

    return Container(
      width: double.infinity,
      height: 430,

      clipBehavior:
          Clip.antiAlias,

      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Stack(
        alignment: Alignment.center,

        children: [
          // ------------------------------------------------------
          // VIDEO
          // ------------------------------------------------------

          FittedBox(
            fit: BoxFit.cover,

            child: SizedBox(
              width:
                  controller.value.size.width,

              height:
                  controller.value.size.height,

              child: VideoPlayer(
                controller,
              ),
            ),
          ),

          // ------------------------------------------------------
          // TAP AREA
          // ------------------------------------------------------

          Positioned.fill(
            child: GestureDetector(
              onTap: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }

                if (mounted) {
                  setState(() {});
                }
              },

              child:
                  const SizedBox.expand(),
            ),
          ),

          // ------------------------------------------------------
          // PLAY ICON
          // ------------------------------------------------------

          if (!controller.value.isPlaying)
            Container(
              width: 72,
              height: 72,

              decoration:
                  const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),

          // ------------------------------------------------------
          // DURATION
          // ------------------------------------------------------

          Positioned(
            right: 12,
            bottom: 12,

            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),

              decoration: BoxDecoration(
                color: Colors.black
                    .withValues(alpha: 0.65),

                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: Text(
                _formatDuration(duration),

                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
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
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,

      hintStyle: TextStyle(
        color: Colors.white
            .withValues(alpha: 0.35),
      ),

      filled: true,

      fillColor:
          const Color(0xFF181818),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white
              .withValues(alpha: 0.05),
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color: _pink,
          width: 1.2,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,

        centerTitle: true,

        title: const Text(
          'Post Video',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,

          padding:
              const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            35,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ------------------------------------------------
              // PREVIEW
              // ------------------------------------------------

              _buildPreview(),

              const SizedBox(
                height: 14,
              ),

              // ------------------------------------------------
              // SELECT VIDEO
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 52,

                child:
                    OutlinedButton.icon(
                  onPressed:
                      _uploading
                          ? null
                          : _pickVideo,

                  icon: const Icon(
                    Icons.video_library_rounded,
                  ),

                  label: Text(
                    _videoFile == null
                        ? 'Choose Video'
                        : 'Change Video',
                  ),

                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        Colors.white,

                    side: BorderSide(
                      color: Colors.white
                          .withValues(
                        alpha: 0.14,
                      ),
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ------------------------------------------------
              // DURATION
              // ------------------------------------------------

              if (_videoFile != null)
                Container(
                  width: double.infinity,

                  padding:
                      const EdgeInsets.all(
                    13,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF171717,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color:
                            Colors.white70,
                      ),

                      const SizedBox(
                        width: 9,
                      ),

                      Text(
                        'Duration: '
                        '${_formatDuration(
                          _videoDuration,
                        )} / 3:00 max',

                        style:
                            const TextStyle(
                          color:
                              Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 22,
              ),

              // ------------------------------------------------
              // CAPTION
              // ------------------------------------------------

              const Text(
                'Caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              TextField(
                controller:
                    _captionController,

                enabled:
                    !_uploading,

                maxLines: 4,

                maxLength: 500,

                style:
                    const TextStyle(
                  color: Colors.white,
                ),

                cursorColor: _pink,

                decoration:
                    _inputDecoration(
                  hint:
                      'Write something about your video...',
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // ------------------------------------------------
              // HASHTAGS
              // ------------------------------------------------

              const Text(
                'Hashtags',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              TextField(
                controller:
                    _hashtagController,

                enabled:
                    !_uploading,

                style:
                    const TextStyle(
                  color: Colors.white,
                ),

                cursorColor: _pink,

                decoration:
                    _inputDecoration(
                  hint:
                      '#PALOK #ShortVideo #Bangladesh',
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // ------------------------------------------------
              // UPLOAD PROGRESS
              // ------------------------------------------------

              if (_uploading) ...[
                Text(
                  _uploadStatus.isEmpty
                      ? 'Uploading video...'
                      : _uploadStatus,

                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                const SizedBox(
                  height: 9,
                ),

                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),

                  child:
                      LinearProgressIndicator(
                    value:
                        _uploadProgress,

                    minHeight: 6,

                    backgroundColor:
                        Colors.white
                            .withValues(
                      alpha: 0.08,
                    ),

                    valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                      _pink,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  '${(
                    _uploadProgress * 100
                  ).toStringAsFixed(0)}%',

                  style:
                      const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),
              ],

              // ------------------------------------------------
              // POST
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 56,

                child:
                    ElevatedButton.icon(
                  onPressed:
                      _uploading
                          ? null
                          : _uploadVideo,

                  icon: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .send_rounded,
                        ),

                  label: Text(
                    _uploading
                        ? 'Posting...'
                        : 'Post Video',

                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        _pink,

                    foregroundColor:
                        Colors.white,

                    disabledBackgroundColor:
                        _pink.withValues(
                      alpha: 0.4,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
