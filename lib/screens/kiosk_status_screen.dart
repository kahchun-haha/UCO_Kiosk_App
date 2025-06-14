import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class KioskStatusScreen extends StatelessWidget {
  KioskStatusScreen({super.key});

  final DocumentReference _docRef =
      FirebaseFirestore.instance.collection('kiosk').doc('status');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Kiosk Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E3440),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
            // Content
            StreamBuilder<DocumentSnapshot>(
                stream: _docRef.snapshots(),
                builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Something went wrong."));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF2E3440)),
                    );
                  }

                  if (snapshot.hasData && snapshot.data!.exists) {
                    Map<String, dynamic> data =
                        snapshot.data!.data() as Map<String, dynamic>;

                    int fillLevel = data['fillLevel'] ?? 0;
                    double weight = (data['weight'] ?? 0.0).toDouble();
                    int liquidHeight = data['liquidHeight'] ?? 0;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Status Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2E3440), Color(0xFF434C5E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.analytics_rounded,
                                  color: Color(0xFF88C999),
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Kiosk Status',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getKioskStatus(fillLevel, weight),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFFD8DEE9),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Quick Metrics
                          _buildMetricsGrid(fillLevel, weight, liquidHeight),
                        ],
                      ),
                    );
                  }

                  return const Center(child: Text("Waiting for data from kiosk..."));
                },
              ),
    );
  }

  Widget _buildMetricsGrid(int fillLevel, double weight, int liquidHeight) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.opacity_rounded,
                title: 'Fill Level',
                value: '$fillLevel%',
                subtitle: 'Current capacity',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.scale_rounded,
                title: 'Weight',
                value: '${weight.round()}g',
                subtitle: 'Total weight',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.height_rounded,
                title: 'Liquid Height',
                value: '${liquidHeight}cm',
                subtitle: 'Current level',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.sensors_rounded,
                title: 'Status',
                value: _getStatusIcon(fillLevel),
                subtitle: _getStatusText(fillLevel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF88C999), size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  String _getKioskStatus(int fillLevel, double weight) {
    if (fillLevel > 80) {
      return 'Kiosk is nearly full and needs attention';
    } else if (fillLevel > 50) {
      return 'Kiosk is operating normally with moderate usage';
    } else if (weight > 0) {
      return 'Kiosk is ready for more recycling materials';
    } else {
      return 'Kiosk is empty and ready to accept materials';
    }
  }

  String _getStatusIcon(int fillLevel) {
    if (fillLevel > 80) {
      return '🔴';
    } else if (fillLevel > 50) {
      return '🟡';
    } else {
      return '🟢';
    }
  }

  String _getStatusText(int fillLevel) {
    if (fillLevel > 80) {
      return 'Nearly full';
    } else if (fillLevel > 50) {
      return 'Moderate';
    } else {
      return 'Available';
    }
  }
}