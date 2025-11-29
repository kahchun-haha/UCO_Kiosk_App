import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About UMinyak',
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
          children: [
            const SizedBox(height: 20),
            // Logo Area
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x10000000), blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.recycling_rounded, size: 60, color: Color(0xFF88C999)),
            ),
            const SizedBox(height: 24),
            const Text(
              "UMinyak Kiosk App",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              "Version 1.0.0 (Beta)",
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),

            const SizedBox(height: 40),

            // Mission Statement
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Our Mission",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "We aim to create a sustainable environment by transforming used cooking oil into renewable energy. By participating, you prevent water pollution and earn rewards for your contribution to a greener planet.",
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legal Menu
            _buildLegalItem(context, "Privacy Policy"),
            const SizedBox(height: 12),
            _buildLegalItem(context, "Terms of Service"),
            const SizedBox(height: 12),
            _buildLegalItem(context, "Open Source Licenses"),

            const SizedBox(height: 40),
            
            Text(
              "© 2025 UMinyak.\nAll rights reserved.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalItem(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
         // Add navigation to webview or dialog
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document placeholder")));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}