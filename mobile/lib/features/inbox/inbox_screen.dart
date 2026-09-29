
import 'package:flutter/material.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  // ০ = অল অ্যাক্টিভিটি, ১ = লাইক, ২ = কমেন্ট, ৩ = ফলোয়ার
  int _selectedFilterIndex = 0;

  final List<String> _filters = [
    'All activity',
    'Likes',
    'Comments',
    'Mentions',
    'Followers'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedFilterIndex,
            dropdownColor: const Color(0xFF1F1F1F),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFilterIndex = newValue;
                });
              }
            },
            items: List.generate(_filters.length, (index) {
              return DropdownMenuItem<int>(
                value: index,
                child: Text(_filters[index]),
              );
            }),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            onPressed: () {
              _openDirectMessagesSheet(context);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ১. একটিভ স্টোরি এবং ইউজার বার
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 6,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildCreateStoryTile();
                  return _buildActiveUserTile(index);
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(color: Colors.white12, height: 1),
          ),

          // ২. নিউ অ্যাক্টিভিটি শর্টকাট
          SliverToBoxAdapter(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.pinkAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 24),
              ),
              title: const Text(
                'New activity',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _filters[_selectedFilterIndex],
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _showActivityFilterModal(context);
              },
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(color: Colors.white12, height: 1),
          ),

          // ৩. মেসেজ হেডার
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Messages',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ৪. ডাইনামিক নোটিফিকেশন/মেসেজ লিস্ট
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 56,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilterIndex == 0
                        ? 'No notifications yet'
                        : 'No ${_filters[_selectedFilterIndex]} yet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Like, comment বা follow এলে এখানে দেখা যাবে',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // স্টোরি অপশন
  Widget _buildCreateStoryTile() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFF262626),
                child: Icon(Icons.person, color: Colors.white, size: 36),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Create', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  // একটিভ ফ্রেন্ড আইকন
  Widget _buildActiveUserTile(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.lightGreenAccent, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              child: Text(
                'U$index',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('User $index', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  // ফিল্টার মোডাল ডায়ালগ
  void _showActivityFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(
                _filters[index],
                style: const TextStyle(color: Colors.white),
              ),
              trailing: _selectedFilterIndex == index
                  ? const Icon(Icons.check, color: Colors.redAccent)
                  : null,
              onTap: () {
                setState(() {
                  _selectedFilterIndex = index;
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  // ডাইরেক্ট মেসেজ পপআপ
  void _openDirectMessagesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Direct Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'No direct messages yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
