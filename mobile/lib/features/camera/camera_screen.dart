import 'package:flutter/material.dart';

class TikTokCameraScreen extends StatefulWidget {
  const TikTokCameraScreen({Key? key}) : super(key: key);

  @override
  State<TikTokCameraScreen> createState() => _TikTokCameraScreenState();
}

class _TikTokCameraScreenState extends State<TikTokCameraScreen> {
  int _selectedTimer = 15; // 15s, 60s, 10m
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ১. ক্যামেরা প্রিভিউ ব্যাকগ্রাউন্ড
            Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.camera_alt, size: 80, color: Colors.white24),
              ),
            ),

            // ২. টপ হেডার (ক্লোজ বাটন ও অ্যাড সাউন্ড)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.music_note, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Add sound',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            // ৩. রাইট সাইডবার (ক্যামেরা কন্ট্রোল ও ইফেক্ট)
            Positioned(
              top: 60,
              right: 12,
              child: Column(
                children: [
                  _buildCameraOption(Icons.flip_camera_ios, 'Flip'),
                  _buildCameraOption(Icons.speed, 'Speed'),
                  _buildCameraOption(Icons.auto_awesome, 'Beauty'),
                  _buildCameraOption(Icons.filter_vintage, 'Filters'),
                  _buildCameraOption(Icons.timer, 'Timer'),
                  _buildCameraOption(Icons.flash_on, 'Flash'),
                ],
              ),
            ),

            // ৪. বটম কন্ট্রোলস (রেকর্ড বাটন, টাইমার, গ্যালারি)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // টাইমার সিলেক্টর (15s / 60s / 10m)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [15, 60, 600].map((time) {
                      bool isSelected = _selectedTimer == time;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTimer = time;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white24 : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            time == 600 ? '10m' : '${time}s',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ক্যাপচার বাটন ও গ্যালারি অপশন
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // ইফেক্টস আইকন
                      Column(
                        children: const [
                          Icon(Icons.face, color: Colors.white, size: 32),
                          SizedBox(height: 4),
                          Text('Effects', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),

                      // প্রধান লাল রেকর্ড বাটন (টিকটক স্টাইল)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isRecording = !_isRecording;
                          });
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 4),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                            ),
                          ),
                        ),
                      ),

                      // গ্যালারি আপলোড বাটন
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey[900],
                            ),
                            child: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                          ),
                          const SizedBox(height: 4),
                          const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOption(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
