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
  static const _cloudName = 'u0jufmrl';
  static const _uploadPreset = 'palok_video_upload';
  static const _maxVideoBytes = 100 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagController =
      TextEditingController();

  File? _videoFile;
  VideoPlayerController? _videoController;

  bool _uploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      final file = File(pickedFile.path);
      final size = await file.length();

      if (size > _maxVideoBytes) {
        _showMessage('ভিডিও 100 MB বা তার কম হতে হবে।');
        return;
      }

      await _videoController?.dispose();

      final controller = VideoPlayerController.file(file);

      await controller.initialize();

      controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoFile = file;
        _videoController = controller;
      });

      await controller.play();
    } catch (e) {
      _showMessage('ভিডিও নির্বাচন করা যায়নি');
    }
  }

  Future<Map<String, dynamic>> _cloudinaryUpload(File file) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
    );

    final boundary =
        '----PALOK${DateTime.now().microsecondsSinceEpoch}';

    final fileLength = await file.length();

    final fileName =
        'palok_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final prefix = '--$boundary\r\n'
        'Content-Disposition: form-data; name="upload_preset"\r\n\r\n'
        '$_uploadPreset\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; '
        'filename="$fileName"\r\n'
        'Content-Type: video/mp4\r\n\r\n';

    final suffix = '\r\n--$boundary--\r\n';

    final prefixBytes = utf8.encode(prefix);
    final suffixBytes = utf8.encode(suffix);

    final total =
        prefixBytes.length + fileLength + suffixBytes.length;

    var sent = 0;

    final request = http.StreamedRequest('POST', uri);

    request.headers['Content-Type'] =
        'multipart/form-data; boundary=$boundary';
    request.headers['Accept'] = 'application/json';
    request.contentLength = total;

    final responseFuture = request.send();

    request.sink.add(prefixBytes);
    sent += prefixBytes.length;
    _setUploadProgress(sent / total, 'Uploading video...');

    await for (final chunk in file.openRead()) {
      request.sink.add(chunk);
      sent += chunk.length;
      _setUploadProgress(sent / total, 'Uploading video...');
    }

    request.sink.add(suffixBytes);
    sent += suffixBytes.length;
    _setUploadProgress(1, 'Processing video...');

    await request.sink.close();

    final response = await responseFuture;
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Cloudinary error (${response.statusCode})';

      try {
        final json = jsonDecode(body) as Map<String, dynamic>;

        if (json['error'] is Map) {
          message =
              ((json['error'] as Map)['message'] ?? message).toString();
        }
      } catch (_) {}

      throw Exception(message);
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }

  void _setUploadProgress(double value, String status) {
    if (!mounted) return;

    setState(() {
      _uploadProgress = value.clamp(0, 1);
      _uploadStatus = status;
    });
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      _showMessage('প্রথমে একটি ভিডিও নির্বাচন করুন');
      return;
    }

    if (_uploading) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('আগে Login করুন।');
      return;
    }

    try {
      setState(() {
        _uploading = true;
        _uploadProgress = 0.0;
        _uploadStatus = 'Preparing video...';
      });

      final data = await _cloudinaryUpload(_videoFile!);

      final videoUrl = (data['secure_url'] ?? '').toString();

      if (videoUrl.isEmpty) {
        throw Exception('Cloudinary URL পাওয়া যায়নি।');
      }

      setState(() {
        _uploadStatus = 'Saving post...';
      });

      final caption = _captionController.text.trim();

      final hashtags = _hashtagController.text
          .trim()
          .split(RegExp(r'[\s,#]+'))
          .where((tag) => tag.isNotEmpty)
          .toList();

      final username =
          user.displayName?.trim().isNotEmpty == true
              ? '@${user.displayName!.trim()}'
              : '@palok_user';

      final videoRef =
          FirebaseFirestore.instance.collection('videos').doc();

      await videoRef.set({
        'ownerId': user.uid,
        'username': username,
        'videoUrl': videoUrl,
        'cloudinaryPublicId': (data['public_id'] ?? '').toString(),
        'cloudinaryAssetId': (data['asset_id'] ?? '').toString(),
        'caption': caption,
        'hashtags': hashtags,
        'soundName': 'Original sound',
        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {'uid': user.uid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadProgress = 1.0;
        _uploadStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉'),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadStatus = '';
      });

      _showMessage(
        'ভিডিও পোস্ট করা যায়নি: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Widget _buildPreview() {
    if (_videoController == null ||
        !_videoController!.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: 430,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
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

    return Container(
      width: double.infinity,
      height: 430,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (_videoController!.value.isPlaying) {
                await _videoController!.pause();
              } else {
                await _videoController!.play();
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
          if (!_videoController!.value.isPlaying)
            const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 70,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Post Video',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreview(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickVideo,
                  icon: const Icon(Icons.video_library),
                  label: Text(
                    _videoFile == null
                        ? 'Choose Original Video'
                        : 'Change Video',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write something about your video...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xff1e1e1e),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hashtags',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hashtagController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '#Palok #ShortVideo #Bangladesh',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xff1e1e1e),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_uploading) ...[
                Text(
                  _uploadStatus.isEmpty
                      ? 'Uploading video...'
                      : _uploadStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _uploadVideo,
                  icon: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _uploading ? 'Posting...' : 'Post Video',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffff176b),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
