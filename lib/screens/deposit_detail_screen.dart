// lib/screens/deposit_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DepositDetailScreen extends StatelessWidget {
  final String depositId;
  const DepositDetailScreen({super.key, required this.depositId});

  String fmt(Timestamp? ts) {
    if (ts == null) return 'Unknown';
    return DateFormat('dd MMM yyyy, h:mm a').format(ts.toDate().toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final deposits = FirebaseFirestore.instance.collection('deposits');

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
          'Deposit Details',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<DocumentSnapshot>(
          future: deposits.doc(depositId).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF88C999)),
              );
            if (!snap.hasData || !snap.data!.exists)
              return const Center(child: Text('Deposit not found'));
            final data = snap.data!.data()! as Map<String, dynamic>;
            final kioskId = data['kioskId'] ?? 'Unknown';
            final weight =
                (data['weight'] is int)
                    ? (data['weight'] as int).toDouble()
                    : (data['weight'] ?? 0.0);
            final points = data['points'] ?? (weight / 10).round();
            final ts = data['timestamp'] as Timestamp?;
            final userId = data['userId'] ?? '';

            // fetch kiosk details
            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('kiosks')
                      .doc(kioskId)
                      .get(),
              builder: (context, kioskSnap) {
                Map<String, dynamic>? kioskData;
                if (kioskSnap.hasData && kioskSnap.data!.exists)
                  kioskData = kioskSnap.data!.data() as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 8),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(weight / 1000).toStringAsFixed(3)} kg',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${weight.toStringAsFixed(2)} g',
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kiosk',
                                    style: TextStyle(color: Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    kioskData != null
                                        ? '${kioskData['name'] ?? kioskId}'
                                        : kioskId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Points',
                                    style: TextStyle(color: Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '+$points',
                                    style: const TextStyle(
                                      color: Color(0xFF88C999),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Timestamp',
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fmt(ts),
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Collected by (userId)',
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            userId,
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // optional: show kiosk location on map or extra kiosk info here
                    if (kioskData != null && kioskData.containsKey('location'))
                      Text(
                        'Location: ${kioskData['location']}',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    const Spacer(),
                    // optional QR receipt download or share
                    ElevatedButton(
                      onPressed: () {
                        // TODO: show QR / generate receipt
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF88C999),
                      ),
                      child: const Text('Show receipt'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
