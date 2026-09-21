import 'dart:convert';
import 'dart:io';
import 'upload_video_screen.dart';
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
  // PALOK UPLOAD CONFIG
  // ============================================================

  static const String _cloudName = 'u0jufmrl';
  static const String _uploadPreset = 'palok_video_upload';

  // Current maximum file size
  static const int _maxVideoBytes = 100 * 1024 * 1024;

  // PALOK short-video maximum duration
  static const Duration _maxVideoDuration = Duration(minutes: 3);

  // ============================================================
  // SERVICES
  // ============================================================

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagController =
      TextEditingController();

  // ============================================================
  // VIDEO STATE
  // ============================================================

  File? _videoFile;
  VideoPlayerController? _videoController;

  Duration _videoDuration = Duration.zero;

  // ============================================================
  // UPLOAD STATE
  // ============================================================

  bool _uploading = false;

  double _uploadProgress = 0.0;

  String _uploadStatus = '';

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
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      final File file = File(pickedFile.path);

      // ----------------------------------------------------------
      // FILE SIZE CHECK
      // ----------------------------------------------------------

      final int fileSize = await file.length();

      if (fileSize > _maxVideoBytes) {
        _showMessage(
          'ভিডিও 100 MB বা তার কম হতে হবে।',
        );

        return;
      }

      // ----------------------------------------------------------
      // OLD CONTROLLER DISPOSE
      // ----------------------------------------------------------

      await _videoController?.dispose();

      _videoController = null;

      // ----------------------------------------------------------
      // CREATE NEW CONTROLLER
      // ----------------------------------------------------------

      final VideoPlayerController controller =
          VideoPlayerController.file(file);

      await controller.initialize();

      final Duration duration = controller.value.duration;

      // ----------------------------------------------------------
      // DURATION CHECK
      // ----------------------------------------------------------

      if (duration > _maxVideoDuration) {
        await controller.dispose();

        _showMessage(
          'ভিডিও সর্বোচ্চ 3 মিনিটের হতে হবে।',
        );

        return;
      }

      controller.setLooping(true);

      // ----------------------------------------------------------
      // MOUNT CHECK
      // ----------------------------------------------------------

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // ----------------------------------------------------------
      // SAVE STATE
      // ----------------------------------------------------------

      setState(() {
        _videoFile = file;
        _videoController = controller;
        _videoDuration = duration;
      });

      // ----------------------------------------------------------
      // PLAY PREVIEW
      // ----------------------------------------------------------

      await controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
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
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
    );

    final String boundary =
        '----PALOK${DateTime.now().microsecondsSinceEpoch}';

    final int fileLength = await file.length();

    final String fileName =
        'palok_${DateTime.now().millisecondsSinceEpoch}.mp4';

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
        'Content-Type: video/mp4\r\n\r\n';

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
    // SEND REQUEST
    // ----------------------------------------------------------

    final Future<http.StreamedResponse> responseFuture =
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
    // VIDEO FILE STREAM
    // ----------------------------------------------------------

    await for (final List<int> chunk
        in file.openRead()) {
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
    // CLOSE REQUEST
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
          'Cloudinary error (${response.statusCode})';

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
      } catch (_) {
        // Ignore JSON parsing error.
      }

      throw Exception(message);
    }

    // ----------------------------------------------------------
    // DECODE
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
  // LOAD PALOK USERNAME
  // ============================================================

  Future<String> _getUsername(User user) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? data =
          snapshot.data();

      if (data != null) {
        final String username =
            (data['username'] ?? '')
                .toString()
                .trim();

        if (username.isNotEmpty) {
          if (username.startsWith('@')) {
            return username;
          }

          return '@$username';
        }
      }
    } catch (_) {
      // If profile loading fails,
      // fallback below will be used.
    }

    // ----------------------------------------------------------
    // FALLBACK
    // ----------------------------------------------------------

    final String displayName =
        user.displayName?.trim() ?? '';

    if (displayName.isNotEmpty) {
      return '@$displayName';
    }

    return '@palok_user';
  }

  // ============================================================
  // HASHTAG PARSER
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
              (String tag) => tag.trim().isNotEmpty,
            )
            .map(
              (String tag) => tag.trim(),
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
    // DURATION CHECK AGAIN
    // ----------------------------------------------------------

    final Duration duration =
        _videoController!.value.duration;

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
      // START UPLOAD
      // --------------------------------------------------------

      setState(() {
        _uploading = true;
        _uploadProgress = 0.0;
        _uploadStatus =
            'ভিডিও প্রস্তুত করা হচ্ছে...';
      });

      // --------------------------------------------------------
      // PAUSE PREVIEW
      // --------------------------------------------------------

      await _videoController?.pause();

      // --------------------------------------------------------
      // GET USERNAME
      // --------------------------------------------------------

      final String username =
          await _getUsername(user);

      // --------------------------------------------------------
      // CLOUDINARY
      // --------------------------------------------------------

      final Map<String, dynamic> data =
          await _cloudinaryUpload(
        _videoFile!,
      );

      // --------------------------------------------------------
      // VIDEO URL
      // --------------------------------------------------------

      final String videoUrl =
          (data['secure_url'] ?? '')
              .toString()
              .trim();

      if (videoUrl.isEmpty) {
        throw Exception(
          'Cloudinary video URL পাওয়া যায়নি।',
        );
      }

      // --------------------------------------------------------
      // CLOUDINARY IDs
      // --------------------------------------------------------

      final String cloudinaryPublicId =
          (data['public_id'] ?? '')
              .toString();

      final String cloudinaryAssetId =
          (data['asset_id'] ?? '')
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
      // CREATE VIDEO DOCUMENT
      // --------------------------------------------------------

      final DocumentReference<Map<String, dynamic>>
          videoRef =
          _firestore
              .collection('videos')
              .doc();

      // --------------------------------------------------------
      // FINAL VIDEO DATA
      // --------------------------------------------------------

      await videoRef.set({
        'ownerId': user.uid,

        'username': username,

        'videoUrl': videoUrl,

        'cloudinaryPublicId':
            cloudinaryPublicId,

        'cloudinaryAssetId':
            cloudinaryAssetId,

        'thumbnailUrl':
            (data['secure_url'] ?? '')
                .toString(),

        'caption': caption,

        'hashtags': hashtags,

        'soundName':
            'Original sound',

        'likeCount': 0,

        'commentCount': 0,

        'saveCount': 0,

        'shareCount': 0,

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      // --------------------------------------------------------
      // ENSURE USER DOCUMENT EXISTS
      // --------------------------------------------------------

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
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
            'ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉',
          ),
          duration:
              Duration(seconds: 2),
        ),
      );

      // --------------------------------------------------------
      // RETURN TO HOME
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

      if (!mounted) {
        return;
      }

      setState(() {
        _uploading = false;
        _uploadStatus = '';
      });

      _showMessage(
        'ভিডিও পোস্ট করা যায়নি:\n'
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
          content: Text(message),
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

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // VIDEO PREVIEW
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
          color: Colors.black,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.video_library_outlined,
            color: Colors.white54,
            size: 70,
          ),
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
        alignment:
            Alignment.center,
        children: [
          // ----------------------------------------------------
          // VIDEO
          // ----------------------------------------------------

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

          // ----------------------------------------------------
          // TAP AREA
          // ----------------------------------------------------

          GestureDetector(
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
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),

          // ----------------------------------------------------
          // PLAY ICON
          // ----------------------------------------------------

          if (!controller.value.isPlaying)
            const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 70,
            ),

          // ----------------------------------------------------
          // DURATION
          // ----------------------------------------------------

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
                color: Colors.black54,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(
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
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBar: AppBar(
        backgroundColor:
            Colors.black,

        foregroundColor:
            Colors.white,

        elevation: 0,

        title: const Text(
          'Post Video',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        centerTitle: true,
      ),

      // --------------------------------------------------------
      // BODY
      // --------------------------------------------------------

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            30,
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
              // VIDEO BUTTON
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
                    Icons.video_library,
                  ),

                  label: Text(
                    _videoFile == null
                        ? 'Choose Original Video'
                        : 'Change Video',
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ------------------------------------------------
              // DURATION INFO
              // ------------------------------------------------

              if (_videoFile != null)
                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(
                    12,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xff171717,
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
                        width: 8,
                      ),

                      Text(
                        'Duration: '
                        '${_formatDuration(
                          _videoDuration,
                        )}'
                        ' / 3:00 max',

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
                height: 20,
              ),

              // ------------------------------------------------
              // CAPTION
              // ------------------------------------------------

              const Text(
                'Caption',

                style: TextStyle(
                  color:
                      Colors.white,

                  fontSize: 16,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              TextField(
                controller:
                    _captionController,

                maxLines: 3,

                maxLength: 500,

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
                      'Write something about your video...',

                  hintStyle:
                      const TextStyle(
                    color:
                        Colors.white54,
                  ),

                  filled: true,

                  fillColor:
                      const Color(
                    0xff1e1e1e,
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              // ------------------------------------------------
              // HASHTAGS
              // ------------------------------------------------

              const Text(
                'Hashtags',

                style: TextStyle(
                  color:
                      Colors.white,

                  fontSize: 16,

                  fontWeight:
                      FontWeight.bold,
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
                  color:
                      Colors.white,
                ),

                decoration:
                    InputDecoration(
                  hintText:
                      '#PALOK #ShortVideo #Bangladesh',

                  hintStyle:
                      const TextStyle(
                    color:
                        Colors.white54,
                  ),

                  filled: true,

                  fillColor:
                      const Color(
                    0xff1e1e1e,
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),
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
                    color:
                        Colors.white,

                    fontSize: 14,
                  ),
                ),

                const SizedBox(
                  height: 8,
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
                    color:
                        Colors.white70,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),
              ],

              // ------------------------------------------------
              // POST BUTTON
              // ------------------------------------------------

              SizedBox(
                width:
                    double.infinity,

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
                            strokeWidth:
                                2,

                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                        ),

                  label: Text(
                    _uploading
                        ? 'Posting...'
                        : 'Post Video',

                    style:
                        const TextStyle(
                      fontSize: 17,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xffff176b,
                    ),

                    foregroundColor:
                        Colors.white,

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
