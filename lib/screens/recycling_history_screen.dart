// lib/screens/recycling_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'deposit_detail_screen.dart';
import 'monthly_chart_widget.dart';
import 'package:uco_kiosk_app/screens/kiosk_list_screen.dart';

enum HistoryFilter { all, thisMonth, lastMonth }

class RecyclingHistoryScreen extends StatefulWidget {
  const RecyclingHistoryScreen({super.key});

  @override
  State<RecyclingHistoryScreen> createState() => _RecyclingHistoryScreenState();
}

class _RecyclingHistoryScreenState extends State<RecyclingHistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;

  Query _buildQuery(String uid) {
    final coll = FirebaseFirestore.instance.collection('deposits');

    // STANDARD: Querying by the standard 'timestamp' field.
    return coll
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true);
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'Unknown Date';
    final dt = ts.toDate().toLocal();
    return DateFormat('dd MMM yyyy, h:mm a').format(dt);
  }

  String _formatKgAndG(double grams) {
    final kg = grams / 1000.0;
    return '${kg.toStringAsFixed(3)} kg (${grams.toStringAsFixed(2)} g)';
  }

  int _computePointsFromWeight(double grams) {
    return (grams / 10).round();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('Recycling History')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    final query = _buildQuery(user.uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recycling History',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Filter Row
            Row(
              children: [
                const Text(
                  'Filter:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                DropdownButton<HistoryFilter>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(
                      value: HistoryFilter.thisMonth,
                      child: Text('This month'),
                    ),
                    DropdownMenuItem(
                      value: HistoryFilter.lastMonth,
                      child: Text('Last month'),
                    ),
                    DropdownMenuItem(
                      value: HistoryFilter.all,
                      child: Text('All'),
                    ),
                  ],
                  onChanged:
                      (v) => setState(() => _filter = v ?? HistoryFilter.all),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonthlyChartScreen(userId: user.uid),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF88C999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Data Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF88C999),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return const Center(child: Text('Something went wrong.'));
                  }

                  final docs = snap.data?.docs ?? [];

                  // OPTIONAL: Client-side filtering logic
                  // Since we removed complex server queries, we filter the list here if needed.
                  final filteredDocs =
                      docs.where((doc) {
                        if (_filter == HistoryFilter.all) return true;

                        final d = doc.data() as Map<String, dynamic>;
                        if (d['timestamp'] == null) return false;

                        final date = (d['timestamp'] as Timestamp).toDate();
                        final now = DateTime.now();

                        if (_filter == HistoryFilter.thisMonth) {
                          return date.year == now.year &&
                              date.month == now.month;
                        } else if (_filter == HistoryFilter.lastMonth) {
                          final lastMonth = DateTime(now.year, now.month - 1);
                          return date.year == lastMonth.year &&
                              date.month == lastMonth.month;
                        }
                        return true;
                      }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 64,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No recycling activity found.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    );
                  }

                  // Calculate Totals
                  double total = 0;
                  int totalPoints = 0;

                  final items =
                      filteredDocs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;

                        final weight =
                            (d['weight'] is int)
                                ? (d['weight'] as int).toDouble()
                                : (d['weight'] ?? 0.0);

                        int points;
                        if (d.containsKey('points')) {
                          final p = d['points'];
                          points =
                              (p is int)
                                  ? p
                                  : (p is double
                                      ? p.round()
                                      : int.tryParse(p.toString()) ?? 0);
                        } else {
                          points = _computePointsFromWeight(weight);
                        }

                        // STANDARD: Direct timestamp usage
                        final ts = d['timestamp'] as Timestamp?;

                        total += weight;
                        totalPoints += points;

                        return {
                          'id': doc.id,
                          'kioskId': d['kioskId'] ?? 'Unknown',
                          'weight': weight,
                          'timestamp': ts,
                          'points': points,
                        };
                      }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E3440), Color(0xFF434C5E)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Recycled',
                                  style: TextStyle(color: Color(0xFFD8DEE9)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(total / 1000).toStringAsFixed(3)} kg',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Points',
                                  style: TextStyle(color: Color(0xFFD8DEE9)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$totalPoints pts',
                                  style: const TextStyle(
                                    color: Color(0xFF88C999),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // List
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final it = items[i];
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => DepositDetailScreen(
                                          depositId: it['id'] as String,
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.inbox_rounded,
                                        color: Color(0xFF88C999),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatKgAndG(
                                              it['weight'] as double,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Kiosk: ${it['kioskId']}',
                                            style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTimestamp(
                                              it['timestamp'] as Timestamp?,
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.stars_rounded,
                                                size: 14,
                                                color: Color(0xFF88C999),
                                              ),
                                              const SizedBox(width: 6),
                                              Text('+${it['points']}'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
