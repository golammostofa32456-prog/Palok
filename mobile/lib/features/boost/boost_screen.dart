import 'package:flutter/material.dart';

import 'boost_controller.dart';
import 'boost_model.dart';

class BoostScreen extends StatefulWidget {
  const BoostScreen({
    super.key,
  });

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  late final BoostController _controller;

  final TextEditingController _videoIdController =
      TextEditingController();

  int _budget = 100;
  int _durationDays = 1;

  @override
  void initState() {
    super.initState();

    _controller = BoostController();

    _controller.watchMyBoosts(
      onChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _videoIdController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createBoost() async {
    FocusScope.of(context).unfocus();

    final videoId = _videoIdController.text.trim();

    if (videoId.isEmpty) {
      _showMessage('প্রথমে Video ID দিন');
      return;
    }

    setState(() {});

    final boostId = await _controller.createBoost(
      videoId: videoId,
      budget: _budget,
      durationDays: _durationDays,
    );

    if (!mounted) return;

    setState(() {});

    if (boostId != null) {
      _videoIdController.clear();

      _showMessage(
        'Boost request সফলভাবে তৈরি হয়েছে',
      );
    } else {
      _showMessage(
        _controller.errorMessage ?? 'Boost তৈরি করা যায়নি',
      );
    }
  }

  Future<void> _cancelBoost(BoostModel boost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: const Text(
            'Cancel Boost?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'আপনি কি এই Boost cancel করতে চান?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('না'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFFFF2D55),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await _controller.cancelBoost(
      boost.id,
    );

    if (!mounted) return;

    setState(() {});

    _showMessage(
      success
          ? 'Boost cancel করা হয়েছে'
          : (_controller.errorMessage ??
              'Boost cancel করা যায়নি'),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Boost',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF2D55),
          backgroundColor: const Color(0xFF181818),
          onRefresh: () async {
            await _controller.loadMyBoosts();

            if (mounted) {
              setState(() {});
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              30,
            ),
            children: [
              _buildCreateCard(),
              const SizedBox(height: 24),
              _buildSectionTitle(),
              const SizedBox(height: 12),
              _buildBoostList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF24131A),
            Color(0xFF111A20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF2D55),
                      Color(0xFF00E5FF),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boost your video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'আপনার ভিডিও আরও মানুষের কাছে পৌঁছাতে Boost করুন',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Video ID',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _videoIdController,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'আপনার video ID লিখুন',
              hintStyle: const TextStyle(
                color: Colors.white30,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              prefixIcon: const Icon(
                Icons.video_library_outlined,
                color: Colors.white54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Budget',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildBudgetSelector(),
          const SizedBox(height: 20),
          const Text(
            'Duration',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildDurationSelector(),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _controller.isLoading ? null : _createBoost,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFF2D55),
                disabledBackgroundColor:
                    Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
              child: _controller.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Create Boost',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSelector() {
    const budgets = [
      100,
      250,
      500,
      1000,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: budgets.map((budget) {
        final selected = _budget == budget;

        return ChoiceChip(
          label: Text(
            '৳$budget',
          ),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _budget = budget;
            });
          },
          selectedColor:
              const Color(0xFFFF2D55),
          backgroundColor:
              Colors.white.withOpacity(0.07),
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector() {
    const durations = [
      1,
      3,
      7,
      14,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: durations.map((days) {
        final selected = _durationDays == days;

        return ChoiceChip(
          label: Text(
            '$days ${days == 1 ? 'Day' : 'Days'}',
          ),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _durationDays = days;
            });
          },
          selectedColor:
              const Color(0xFF00AFC5),
          backgroundColor:
              Colors.white.withOpacity(0.07),
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle() {
    return const Row(
      children: [
        Text(
          'My Boosts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Spacer(),
        Icon(
          Icons.analytics_outlined,
          color: Colors.white54,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildBoostList() {
    if (_controller.boosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 35,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              color: Colors.white30,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'এখনও কোনো Boost নেই',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'উপর থেকে একটি ভিডিও Boost করুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _controller.boosts.map(
        _buildBoostCard,
      ).toList(),
    );
  }

  Widget _buildBoostCard(BoostModel boost) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(
                    boost.status,
                  ).withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: _statusColor(
                    boost.status,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video: ${boost.videoId}',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _buildStatusChip(
                      boost.status,
                    ),
                  ],
                ),
              ),
              Text(
                '৳${boost.budget}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  Icons.visibility_outlined,
                  'Impressions',
                  '${boost.impressions}',
                ),
              ),
              Expanded(
                child: _buildStat(
                  Icons.touch_app_outlined,
                  'Clicks',
                  '${boost.clicks}',
                ),
              ),
              Expanded(
                child: _buildStat(
                  Icons.calendar_today_outlined,
                  'Days',
                  '${boost.durationDays}',
                ),
              ),
            ],
          ),
          if (boost.status != 'cancelled' &&
              boost.status != 'completed' &&
              boost.status != 'rejected') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: _controller.isLoading
                    ? null
                    : () => _cancelBoost(boost),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(0xFFFF2D55),
                  side: const BorderSide(
                    color: Color(0x55FF2D55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel Boost',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 17,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _statusColor(status)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF00E5FF);

      case 'active':
        return const Color(0xFF35D07F);

      case 'completed':
        return const Color(0xFF8B8BFF);

      case 'cancelled':
        return const Color(0xFFFF2D55);

      case 'rejected':
        return const Color(0xFFFF6B6B);

      case 'pending':
      default:
        return const Color(0xFFFFC857);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'APPROVED';

      case 'active':
        return 'ACTIVE';

      case 'completed':
        return 'COMPLETED';

      case 'cancelled':
        return 'CANCELLED';

      case 'rejected':
        return 'REJECTED';

      case 'pending':
      default:
        return 'PENDING';
    }
  }
}
