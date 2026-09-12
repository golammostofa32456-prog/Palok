import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _hashtagController =
      TextEditingController();

  File? _videoFile;
  VideoPlayerController? _videoController;

  bool _uploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // PICK VIDEO
  // ------------------------------------------------------------

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      await _videoController?.dispose();

      final controller = VideoPlayerController.file(
        File(pickedFile.path),
      );

      await controller.initialize();

      controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoFile = File(pickedFile.path);
        _videoController = controller;
      });

      await controller.play();
    } catch (e) {
      _showMessage('ভিডিও নির্বাচন করা যায়নি');
    }
  }

  // ------------------------------------------------------------
  // UPLOAD VIDEO
  // ------------------------------------------------------------

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      _showMessage('প্রথমে একটি ভিডিও নির্বাচন করুন');
      return;
    }

    if (_uploading) {
      return;
    }

    try {
      setState(() {
        _uploading = true;
        _uploadProgress = 0.0;
      });

      User? user = FirebaseAuth.instance.currentUser;

      // যদি লগইন করা না থাকে, Anonymous login করার চেষ্টা করবে।
      if (user == null) {
        try {
          final credential =
              await FirebaseAuth.instance.signInAnonymously();

          user = credential.user;
        } catch (e) {
          throw Exception(
            'Firebase Authentication চালু নেই।',
          );
        }
      }

      if (user == null) {
        throw Exception('User পাওয়া যায়নি');
      }

      final String userId = user.uid;

      final String videoId =
          FirebaseFirestore.instance.collection('videos').doc().id;

      final String storagePath =
          'videos/$userId/$videoId.mp4';

      final Reference storageRef =
          FirebaseStorage.instance.ref().child(storagePath);

      final UploadTask uploadTask =
          storageRef.putFile(
        _videoFile!,
        SettableMetadata(
          contentType: 'video/mp4',
        ),
      );

      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (!mounted) {
            return;
          }

          final total = snapshot.totalBytes;

          if (total > 0) {
            setState(() {
              _uploadProgress =
                  snapshot.bytesTransferred / total;
            });
          }
        },
      );

      final TaskSnapshot snapshot =
          await uploadTask;

      final String videoUrl =
          await snapshot.ref.getDownloadURL();

      final String caption =
          _captionController.text.trim();

      final String hashtags =
          _hashtagController.text.trim();

      // --------------------------------------------------------
      // FIRESTORE POST
      // --------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .set({
        'videoId': videoId,
        'ownerId': userId,
        'videoUrl': videoUrl,
        'caption': caption,
        'hashtags': hashtags,
        'soundName': 'Original Sound - PALOK',

        'likeCount': 0,
        'commentCount': 0,
        'saveCount': 0,
        'shareCount': 0,

        'createdAt': FieldValue.serverTimestamp(),

        'isPublic': true,
      });

      // --------------------------------------------------------
      // USER DOCUMENT
      // --------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(
        {
          'uid': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploading = false;
        _uploadProgress = 1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ভিডিও সফলভাবে PALOK-এ পোস্ট হয়েছে 🎉',
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _uploading = false;
      });

      _showMessage(
        'ভিডিও পোস্ট করা যায়নি: ${e.toString()}',
      );
    }
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showMessage(String message) {
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

  // ------------------------------------------------------------
  // VIDEO PREVIEW
  // ------------------------------------------------------------

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
              child: VideoPlayer(
                _videoController!,
              ),
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

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // VIDEO
              // ------------------------------------------------

              _buildPreview(),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // SELECT VIDEO
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                      _uploading ? null : _pickVideo,
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

              const SizedBox(height: 20),

              // ------------------------------------------------
              // CAPTION
              // ------------------------------------------------

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
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Write something about your video...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: const Color(0xff1e1e1e),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ------------------------------------------------
              // HASHTAGS
              // ------------------------------------------------

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
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText:
                      '#Palok #ShortVideo #Bangladesh',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: const Color(0xff1e1e1e),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------------
              // UPLOAD PROGRESS
              // ------------------------------------------------

              if (_uploading) ...[
                const Text(
                  'Uploading video...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 8),

                LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 6,
                  borderRadius:
                      BorderRadius.circular(10),
                ),

                const SizedBox(height: 8),

                Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 18),
              ],

              // ------------------------------------------------
              // POST BUTTON
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed:
                      _uploading ? null : _uploadVideo,
                  icon: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                        ),
                  label: Text(
                    _uploading
                        ? 'Posting...'
                        : 'Post Video',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xffff176b),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
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
