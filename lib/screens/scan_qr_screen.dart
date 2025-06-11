// screens/scan_qr_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uco_kiosk_app/services/auth_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _authService = AuthService();
  String _qrCode = '';

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      final qrCode = _authService.generateUniqueQrCode(user.uid);
      setState(() {
        _qrCode = qrCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Your QR Code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Show this QR code to the kiosk scanner',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // QR Code Container
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_qrCode.isNotEmpty)
                      QrImageView(
                        data: _qrCode,
                        version: QrVersions.auto,
                        size: 280,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E3440),
                      )
                    else
                      const SizedBox(
                        height: 280,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF88C999),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _qrCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'How to use:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Position this QR code in front of the kiosk scanner\n2. Wait for the green light confirmation\n3. Pour your used cooking oil into the container\n4. Collect your points automatically',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E40AF),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}