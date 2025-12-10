import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EnvironmentalImpactScreen extends StatelessWidget {
  const EnvironmentalImpactScreen({super.key});

  Future<Map<String, double>> _loadImpact() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'totalGrams': 0,
        'totalKg': 0,
        'totalLiters': 0,
        'co2SavedKg': 0,
        'waterProtectedLiters': 0,
      };
    }

    final snap = await FirebaseFirestore.instance
        .collection('deposits')
        .where('userId', isEqualTo: user.uid)
        .get();

    double totalGrams = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final weight = data['weight'];
      if (weight is int) {
        totalGrams += weight.toDouble();
      } else if (weight is double) {
        totalGrams += weight;
      }
    }

    final totalKg = totalGrams / 1000.0;
    // Approx cooking oil density ~0.92 kg/L → 1 L ≈ 920 g
    final totalLiters = totalGrams / 920.0;

    // Assumptions (explain in your FYP report)
    const co2PerLiterKg = 2.5; // kg CO₂e avoided per liter UCO recycled
    const waterPollutionPerLiter = 1000.0; // L water protected per liter UCO

    final co2SavedKg = totalLiters * co2PerLiterKg;
    final waterProtectedLiters = totalLiters * waterPollutionPerLiter;

    return {
      'totalGrams': totalGrams,
      'totalKg': totalKg,
      'totalLiters': totalLiters,
      'co2SavedKg': co2SavedKg,
      'waterProtectedLiters': waterProtectedLiters,
    };
  }

  String _fmt(double v, {int decimals = 2}) => v.toStringAsFixed(decimals);
  String _fmtInt(double v) => NumberFormat.decimalPattern().format(v.round());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Environmental Impact',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E3440),
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _loadImpact(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF88C999),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(
              child: Text(
                'No impact data available yet.',
                style: TextStyle(color: Color(0xFF4B5563)),
              ),
            );
          }

          final data = snap.data!;
          final totalKg = data['totalKg'] ?? 0;
          final totalLiters = data['totalLiters'] ?? 0;
          final co2SavedKg = data['co2SavedKg'] ?? 0;
          final waterProtectedLiters = data['waterProtectedLiters'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Recycling Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total UCO recycled: ${_fmt(totalKg)} kg '
                          '(${_fmt(totalLiters)} L)',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Thank you for supporting SDG 12: Responsible Consumption and Production.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _ImpactCard(
                  icon: Icons.cloud_done_rounded,
                  title: 'CO₂ Emissions Avoided',
                  value: '${_fmt(co2SavedKg)} kg CO₂e',
                  description:
                      'Recycling used cooking oil instead of dumping it allows it to be turned into biodiesel, '
                      'which produces fewer greenhouse gas emissions compared to fossil diesel.',
                ),
                const SizedBox(height: 12),

                _ImpactCard(
                  icon: Icons.water_drop_rounded,
                  title: 'Water Protected',
                  value: '${_fmtInt(waterProtectedLiters)} L',
                  description:
                      'When UCO is poured into sinks or drains, it can pollute rivers and clog wastewater systems. '
                      'Proper recycling helps protect clean water resources.',
                ),
                const SizedBox(height: 12),

                _ImpactCard(
                  icon: Icons.autorenew_rounded,
                  title: 'Circular Economy Impact',
                  value: 'From Waste to Resource',
                  description:
                      'Your used cooking oil can be converted into biodiesel or eco-products like soap. '
                      'This keeps materials in use for longer and reduces waste — a key principle of the circular economy.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const _ImpactCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF88C999).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
