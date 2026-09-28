
import 'package:flutter/material.dart';

class BoostPaymentScreen extends StatefulWidget {
  final String boostId;
  final int amount;

  const BoostPaymentScreen({
    super.key,
    required this.boostId,
    required this.amount,
  });

  @override
  State<BoostPaymentScreen> createState() =>
      _BoostPaymentScreenState();
}

class _BoostPaymentScreenState
    extends State<BoostPaymentScreen> {
  String _selectedMethod = 'bkash';
  bool _processing = false;

  final TextEditingController _phoneController =
      TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continuePayment() async {
    FocusScope.of(context).unfocus();

    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showMessage('Payment number দিন');
      return;
    }

    if (phone.length < 11) {
      _showMessage('সঠিক mobile number দিন');
      return;
    }

    setState(() {
      _processing = true;
    });

    /*
     * এখানে এখনো কোনো real payment gateway যুক্ত করা হয়নি।
     *
     * পরবর্তীতে এখানে bKash/Nagad/Card gateway-এর
     * official payment flow যুক্ত করা হবে।
     */

    await Future<void>.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      _processing = false;
    });

    _showPaymentInfo();
  }

  void _showPaymentInfo() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: const Text(
            'Payment Gateway',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Payment gateway এখনো সংযুক্ত করা হয়নি। '
            'এই জায়গায় পরে official bKash/Nagad/Card '
            'payment flow যুক্ত করা হবে।',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ঠিক আছে'),
            ),
          ],
        );
      },
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
          'Boost Payment',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            30,
          ),
          children: [
            _buildAmountCard(),
            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentMethod(
              id: 'bkash',
              title: 'bKash',
              subtitle: 'Mobile payment',
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 10),
            _buildPaymentMethod(
              id: 'nagad',
              title: 'Nagad',
              subtitle: 'Mobile payment',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 10),
            _buildPaymentMethod(
              id: 'card',
              title: 'Card',
              subtitle: 'Debit / Credit card',
              icon: Icons.credit_card_rounded,
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Number',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: '01XXXXXXXXX',
                hintStyle: const TextStyle(
                  color: Colors.white30,
                ),
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'আপনার নির্বাচিত payment method-এর নম্বর দিন।',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _processing ? null : _continuePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFF2D55),
                  disabledBackgroundColor:
                      Colors.white12,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continue • ৳${widget.amount}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            _buildSecurityNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
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
              Icons.lock_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Boost Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Selected Boost-এর payment',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '৳${widget.amount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedMethod == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x22FF2D55)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF2D55)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? const Color(0xFFFF2D55)
                  : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white38,
            size: 19,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Payment তথ্য নিরাপদ রাখুন। '
              'PIN বা OTP কারও সঙ্গে শেয়ার করবেন না।',
              style: TextStyle(
                color: Colors.white45,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
