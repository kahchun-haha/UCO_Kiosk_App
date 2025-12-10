import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RedemptionHistoryScreen extends StatelessWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Redemption History'),
          backgroundColor: const Color(0xFF2E3440),
        ),
        body: const Center(
          child: Text('Please sign in to view reward history'),
        ),
      );
    }

    // ✅ Simple query: only filter by userId, no orderBy → no index issues
    final query = FirebaseFirestore.instance
        .collection('redemptions')
        .where('userId', isEqualTo: user.uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Reward History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E3440),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF88C999)),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No reward redemptions yet.\nRedeem a reward to see it here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
            );
          }

          // ✅ Sort locally by redeemedAt (newest first)
          final docs = [...snap.data!.docs];
          docs.sort((a, b) {
            final ad = (a['redeemedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bd = (b['redeemedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bd.compareTo(ad);
          });

          final dateFmt = DateFormat('dd MMM yyyy, h:mm a');

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final rewardName = data['rewardName'] ?? 'Reward';
              final cost = data['cost'] ?? 0;
              final status = (data['status'] ?? 'pending').toString();
              final ts = data['redeemedAt'] as Timestamp?;
              final dt = ts?.toDate().toLocal();
              final dateText = dt != null ? dateFmt.format(dt) : 'Unknown date';

              Color statusColor;
              switch (status) {
                case 'completed':
                  statusColor = const Color(0xFF10B981);
                  break;
                case 'cancelled':
                  statusColor = const Color(0xFFEF4444);
                  break;
                default:
                  statusColor = const Color(0xFFF59E0B);
              }

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    rewardName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Cost: $cost pts',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
