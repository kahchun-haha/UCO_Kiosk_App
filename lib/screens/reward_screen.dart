// reward_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // I added 'icon' data to your list to make the UI pop more.
    final rewards = [
      {
        'name': 'Eco Soap',
        'cost': 100,
        'icon': Icons.soap_rounded,
        'desc': 'Biodegradable cleaning soap',
      },
      {
        'name': '500g Cooking Oil',
        'cost': 150,
        'icon': Icons.water_drop_rounded,
        'desc': 'Fresh recycled cooking oil',
      },
      // Added a dummy item just to show how the grid looks with more items
      {
        'name': 'RM10 Voucher',
        'cost': 500,
        'icon': Icons.local_offer_rounded,
        'desc': 'Discount for local partners',
      },
    ];

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF88C999)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Matches Profile background
      appBar: AppBar(
        title: const Text(
          "Rewards Store",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF88C999)),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Unable to load points data"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final int userPoints = userData['points'] ?? 0;

          return Column(
            children: [
              // 1. Top Section: Points Wallet Card
              // Styled exactly like the Profile Header for consistency
              // 1. IMPROVED: Compact Top Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Container(
                  width: double.infinity,
                  // Reduced padding inside the card
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3440), Color(0xFF434C5E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(
                      20,
                    ), // Slightly smaller radius
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x30000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  // Changed Column to Row for horizontal layout
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Side: Label
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Available Balance",
                            style: TextStyle(
                              color: Color(0xFFD8DEE9),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Wallet", // Added a small sub-label or just keep it simple
                            style: TextStyle(
                              color: Color(0xFF88C999),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Right Side: Big Points Display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$userPoints',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32, // Slightly smaller font
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Column(
                            children: [
                              SizedBox(height: 6), // Aligns PTS slightly lower
                              Text(
                                'PTS',
                                style: TextStyle(
                                  color: Color(0xFF88C999),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Rewards Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    // CHANGE THIS: 0.65 was too tall. 0.8 or 0.85 is better balanced.
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: rewards.length,
                  itemBuilder: (context, index) {
                    final item = rewards[index];
                    final String name = item['name'] as String;
                    final int cost = item['cost'] as int;
                    final IconData icon = item['icon'] as IconData;
                    final String desc = item['desc'] as String;
                    final bool canAfford = userPoints >= cost;

                    return _buildRewardCard(
                      context: context,
                      name: name,
                      cost: cost,
                      icon: icon,
                      description: desc,
                      canAfford: canAfford,
                      userUid: user.uid,
                      currentPoints: userPoints,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRewardCard({
    required BuildContext context,
    required String name,
    required int cost,
    required IconData icon,
    required String description,
    required bool canAfford,
    required String userUid,
    required int currentPoints,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Header (Takes up less space now: Flex 2)
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 40, // Slightly smaller icon to fit better
                  color: canAfford ? const Color(0xFF88C999) : Colors.grey[400],
                ),
              ),
            ),
          ),

          // Content (Takes up more relative space: Flex 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10.0), // Tighter padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15, // Slightly smaller font
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2), // Tighter spacing
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11, // Slightly smaller font
                          color: Color(0xFF9CA3AF),
                          height: 1.1, // Tighter line height
                        ),
                      ),
                    ],
                  ),

                  // Price and Button Row
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$cost PTS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color:
                              canAfford
                                  ? const Color(0xFF88C999)
                                  : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 4), // Tighter spacing
                      SizedBox(
                        width: double.infinity,
                        height: 32, // Slightly shorter button
                        child: ElevatedButton(
                          onPressed:
                              canAfford
                                  ? () => _showConfirmationDialog(
                                    context,
                                    name,
                                    cost,
                                    userUid,
                                    currentPoints,
                                  )
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF88C999),
                            disabledBackgroundColor: Colors.grey[200],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            canAfford
                                ? "Redeem"
                                : "Short ${cost - currentPoints}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    String itemName,
    int cost,
    String uid,
    int currentPoints,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Confirm Redemption',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redeem $itemName for $cost points?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFF97316),
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Make sure you are close to the IoT kiosk to collect your item.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF88C999),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _processRedemption(context, uid, currentPoints, cost, itemName);
    }
  }

  Future<void> _processRedemption(
    BuildContext context,
    String uid,
    int currentPoints,
    int cost,
    String itemName,
  ) async {
    try {
      // 1. Update Firebase
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'points': currentPoints - cost,
      });

      if (!context.mounted) return;

      // 2. Show Success Dialog
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF88C999),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Redemption Successful!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You have redeemed $itemName.\nPlease collect it from the kiosk.",
                    style: const TextStyle(color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF88C999),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error redeeming: $e')));
    }
  }
}
