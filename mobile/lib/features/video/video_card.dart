import 'package:flutter/material.dart';
import '../video/video_post.dart';

class SearchScreen extends StatefulWidget {
  final List<VideoPost> videos;
  final Function(int) onVideoSelected;

  const SearchScreen({
    super.key,
    required this.videos,
    required this.onVideoSelected,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoPost> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final results = widget.videos.where((video) {
      final username = video.username.toLowerCase();
      final caption = video.caption.toLowerCase();
      final searchLower = query.toLowerCase();
      
      return username.contains(searchLower) || caption.contains(searchLower);
    }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // টিকটক ডার্ক থিম ব্যাকগ্রাউন্ড
      body: SafeArea(
        // SafeArea এর কারণে সার্চ বার কখনোই নোটিফিকেশন বার বা ক্যামেরা নচের পেছনে ঢাকা পড়বে না
        child: Column(
          children: [
            // সার্চ বার এবং ব্যাক বাটন এরিয়া (ওপরের অতিরিক্ত মার্জিন যুক্ত করা হয়েছে)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616), // কাস্টম ডার্ক গ্রে ইনপুট ব্যাকগ্রাউন্ড
                        borderRadius: BorderRadius.circular(4), // টিকটক স্টাইল স্কয়ারিশ কর্নার
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _handleSearch,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'ব্যবহারকারী বা ভিডিও খুঁজুন',
                          hintStyle: const TextStyle(color: Color(0xFF868686), fontSize: 15),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF868686), size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white60, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _handleSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _handleSearch(_searchController.text),
                    child: const Text(
                      'খুঁজুন',
                      style: TextStyle(
                        color: Color(0xFFFF2D75), // পালক/টিকটক পিঙ্ক কালার থিম
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF121212)),
            
            // সার্চ রেজাল্ট অথবা ডিফল্ট এম্পটি স্ক্রিন এরিয়া
            Expanded(
              child: !_isSearching
                  ? _buildEmptyState()
                  : _searchResults.isEmpty
                      ? _buildNoResultsState()
                      : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  // ডিফল্ট স্ক্রিন ভিউ (কিবোর্ড ওপেন হওয়ার কারণে স্ক্রল-বান্ধব করা হয়েছে)
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              size: 74,
              color: Color(0xFF262626),
            ),
            const SizedBox(height: 16),
            const Text(
              'ব্যবহারকারী বা ভিডিও খুঁজুন',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'নাম, ইউজারনেম বা হ্যাশট্যাগ লিখুন',
              style: TextStyle(
                color: Color(0xFF868686),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 80), // কিবোর্ড খোলার পর কন্টেন্ট ব্যালেন্স করার স্পেস
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Text(
        'কোনো ফলাফল পাওয়া যায়নি।',
        style: TextStyle(color: Color(0xFF868686), fontSize: 15),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final video = _searchResults[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF161616),
            child: Icon(Icons.person, color: Colors.white70),
          ),
          title: Text(
            video.username,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            video.caption,
            style: const TextStyle(color: Color(0xFF868686)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            final actualIndex = widget.videos.indexOf(video);
            if (actualIndex != -1) {
              widget.onVideoSelected(actualIndex);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
}
