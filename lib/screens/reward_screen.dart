// screens/reward_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  final AuthService _authService = AuthService();
  int _userPoints = 0;
  bool _isLoading = true;

  final List<RewardItem> _rewards = [
    RewardItem(
      id: '1',
      title: 'Eco Shopping Bag',
      description: 'Reusable shopping bag made from recycled materials',
      points: 50,
      icon: Icons.shopping_bag_rounded,
      available: true,
    ),
    RewardItem(
      id: '2',
      title: 'Coffee Voucher',
      description: 'Free coffee at participating cafes',
      points: 100,
      icon: Icons.local_cafe_rounded,
      available: true,
    ),
    RewardItem(
      id: '3',
      title: 'Plant Seedling Kit',
      description: 'Grow your own herbs at home',
      points: 150,
      icon: Icons.eco_rounded,
      available: true,
    ),
    RewardItem(
      id: '4',
      title: 'Meal Voucher',
      description: 'RM10 voucher at local restaurants',
      points: 200,
      icon: Icons.restaurant_rounded,
      available: true,
    ),
    RewardItem(
      id: '5',
      title: 'Eco Bottle',
      description: 'Stainless steel water bottle',
      points: 300,
      icon: Icons.water_drop_rounded,
      available: true,
    ),
    RewardItem(
      id: '6',
      title: 'Gift Card RM50',
      description: 'Shopping voucher for sustainable products',
      points: 500,
      icon: Icons.card_giftcard_rounded,
      available: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
  }

  Future<void> _loadUserPoints() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      final userDoc = await _authService.getUserData(user.uid);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userPoints = userData['points'] ?? 0;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _redeemReward(RewardItem reward) async {
    if (_userPoints < reward.points) {
      _showInsufficientPointsDialog();
      return;
    }

    final confirm = await _showConfirmDialog(reward);
    if (confirm == true) {
      try {
        final user = _authService.getCurrentUser();
        if (user != null) {
          // Deduct points
          await _authService.updateUserPoints(user.uid, -reward.points);
          
          // Record redemption
          await FirebaseFirestore.instance
              .collection('redemptions')
              .add({
            'userId': user.uid,
            'rewardId': reward.id,
            'rewardTitle': reward.title,
            'pointsUsed': reward.points,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

          setState(() {
            _userPoints -= reward.points;
          });

          _showSuccessDialog(reward);
        }
      } catch (e) {
        _showErrorDialog('Failed to redeem reward. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Color(0xFF2E3440),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rewards',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Points Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF88C999),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR POINTS',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : Text(
                                '$_userPoints',
                                style: const TextStyle(
                                  fontSize: 36,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Rewards List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E3440),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _rewards.length,
                      itemBuilder: (context, index) {
                        final reward = _rewards[index];
                        final canAfford = _userPoints >= reward.points;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: reward.available && canAfford
                                  ? () => _redeemReward(reward)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    // Reward Icon
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: reward.available && canAfford
                                            ? const Color(0xFF88C999).withOpacity(0.1)
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        reward.icon,
                                        size: 28,
                                        color: reward.available && canAfford
                                            ? const Color(0xFF88C999)
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 16),
                                    
                                    // Reward Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reward.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: reward.available && canAfford
                                                  ? const Color(0xFF1F2937)
                                                  : const Color(0xFF9CA3AF),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            reward.description,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF6B7280),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.stars_rounded,
                                                size: 16,
                                                color: reward.available && canAfford
                                                    ? const Color(0xFF88C999)
                                                    : const Color(0xFF9CA3AF),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${reward.points} points',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: reward.available && canAfford
                                                      ? const Color(0xFF88C999)
                                                      : const Color(0xFF9CA3AF),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Status Icon
                                    if (!reward.available)
                                      const Icon(
                                        Icons.lock_rounded,
                                        color: Color(0xFF9CA3AF),
                                        size: 20,
                                      )
                                    else if (!canAfford)
                                      const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Color(0xFF9CA3AF),
                                        size: 20,
                                      )
                                    else
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Color(0xFF88C999),
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(RewardItem reward) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Confirm Redemption',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Redeem ${reward.title} for ${reward.points} points?',
              style: const TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Remaining points:',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${_userPoints - reward.points}',
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF88C999),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  void _showInsufficientPointsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Insufficient Points',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'You don\'t have enough points for this reward. Keep recycling to earn more points!',
          style: TextStyle(
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF88C999),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(RewardItem reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Redemption Successful!',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have successfully redeemed ${reward.title}. Please collect your reward at the designated counter.',
          style: const TextStyle(
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Error',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class RewardItem {
  final String id;
  final String title;
  final String description;
  final int points;
  final IconData icon;
  final bool available;

  RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    required this.available,
  });
}