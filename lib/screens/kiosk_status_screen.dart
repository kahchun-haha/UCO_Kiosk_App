import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uco_kiosk_app/services/notification_service.dart';

class KioskStatusScreen extends StatefulWidget {
  // --- ADDED THIS ---
  // This variable will hold the ID passed from the home screen
  final String kioskId;

  // --- MODIFIED THIS ---
  // The constructor now requires the kioskId
  const KioskStatusScreen({super.key, required this.kioskId});

  @override
  State<KioskStatusScreen> createState() => _KioskStatusScreenState();
}

class _KioskStatusScreenState extends State<KioskStatusScreen> {
  // --- MODIFIED THIS ---
  // Removed 'final' and will initialize it in initState
  late DocumentReference _docRef;

  final NotificationService _notificationService = NotificationService();
  bool _notificationSent = false;

  @override
  void initState() {
    super.initState();
    _notificationService.init();

    // --- ADDED THIS ---
    // Initialize the document reference using the kioskId from the widget
    _docRef = FirebaseFirestore.instance
        .collection('kiosks')
        .doc(widget.kioskId);
  }

  @override
  Widget build(BuildContext context) {
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
          'Kiosk Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream:
            _docRef.snapshots(), // This will now listen to the correct document
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

            if (fillLevel > 80 && !_notificationSent) {
              _notificationService.showNotification(
                'Kiosk Alert',
                'Kiosk is nearly full and needs attention.',
              );

              // Use a post-frame callback to safely update the state after the build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _notificationSent = true;
                  });
                }
              });
            } else if (fillLevel <= 80 && _notificationSent) {
              // Reset the flag if the fill level goes back to normal.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _notificationSent = false;
                  });
                }
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
    if (fillLevel >= 80) {
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
    if (fillLevel >= 80) {
      return '🔴';
    } else if (fillLevel >= 50) {
      return '🟡';
    } else {
      return '🟢';
    }
  }

  String _getStatusText(int fillLevel) {
    if (fillLevel >= 80) {
      return 'Nearly full';
    } else if (fillLevel > 50) {
      return 'Moderate';
    } else {
      return 'Available';
    }
  }
}
