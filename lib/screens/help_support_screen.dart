import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // --- OPEN EMAIL ---
  Future<void> _contactSupport(BuildContext context) async {
    const String email = 'UMinyak@gmail.com';

    const String rawSubject = 'UMinyak Support Request';
    const String rawBody =
        'Hi UMinyak team,\n\n'
        'I need help with...\n\n'
        '(Please describe your issue here.)';

    // Force proper URL encoding (spaces -> %20, newlines -> %0A, etc.)
    final String encodedSubject = Uri.encodeComponent(rawSubject);
    final String encodedBody = Uri.encodeComponent(rawBody);

    final Uri emailUri = Uri.parse(
      'mailto:$email?subject=$encodedSubject&body=$encodedBody',
    );

    final launched = await launchUrl(
      emailUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app found on this device.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
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
          'Help & Support',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),

            _buildFaqItem(
              question: "How do I earn points?",
              answer:
                  "Scan your QR code at the kiosk, pour your UCO (Used Cooking Oil), and the smart scale will automatically calculate points based on the weight.",
            ),
            _buildFaqItem(
              question: "Where are the kiosks located?",
              answer:
                  "You can find nearby kiosks using the 'Find Kiosk' button on your 'Home' tab.",
            ),
            _buildFaqItem(
              question: "What type of oil can I recycle?",
              answer:
                  "We accept all vegetable-based cooking oils (e.g., palm, canola, sunflower). Please do not recycle motor oil or water-contaminated oil.",
            ),
            _buildFaqItem(
              question: "My points didn't update.",
              answer:
                  "Points usually update instantly, but may take up to 5 minutes depending on network connection. Check your 'Recycling History' for details.",
            ),

            const SizedBox(height: 32),

            const Text(
              'Still need help?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),

            // Contact Support Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.headset_mic_rounded,
                    size: 48,
                    color: Color(0xFF88C999),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Our support team is available\n Mon–Fri, 9am – 6pm.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Email: UMinyak@gmail.com",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Phone: 03-7967 6300",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _contactSupport(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF88C999),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF88C999),
          collapsedIconColor: const Color(0xFF9CA3AF),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding:
              const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(
            question,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1F2937),
            ),
          ),
          children: [
            Text(
              answer,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
