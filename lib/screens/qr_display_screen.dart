// screens/qr_display_screen.dart
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uco_kiosk_app/services/auth_service.dart';

class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFunctions _functions =
    FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  String _token = '';
  int _expiresInSeconds = 60;
  int _secondsLeft = 0;

  DateTime? _expiresAt; // ✅ NEW: absolute expiry time from server

  bool _loading = false;

  Timer? _countdownTimer;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initQrFlow();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------
  // INIT
  // --------------------------------------------------
  Future<void> _initQrFlow() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    await _createNewQrToken();

    // ✅ Countdown timer: compute from _expiresAt (not "minus 1" forever)
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final exp = _expiresAt;
      if (exp == null) return;

      final diff = exp.difference(DateTime.now()).inSeconds;
      final left = diff < 0 ? 0 : diff;

      if (_secondsLeft != left) {
        setState(() => _secondsLeft = left);
      }
    });
  }

  // --------------------------------------------------
  // AUTO-REFRESH SCHEDULER (one-shot, resets every new token)
  // --------------------------------------------------
  void _scheduleAutoRefresh() {
    _autoRefreshTimer?.cancel();

    // refresh ~15s before expiry, but never less than 5s
    final seconds = (_expiresInSeconds - 15).clamp(5, _expiresInSeconds);

    _autoRefreshTimer = Timer(Duration(seconds: seconds), () async {
      await _createNewQrToken();
    });
  }

  // --------------------------------------------------
  // CREATE QR TOKEN
  // --------------------------------------------------
  Future<void> _createNewQrToken() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final callable = _functions.httpsCallable('createQrSession');
      final res = await callable.call();

      final data = Map<String, dynamic>.from(res.data);

      final token = (data['token'] ?? '') as String;
      final expiresIn = (data['expiresInSeconds'] ?? 60) as int;

      // ✅ Use server-provided expiresAtMs if available
      DateTime? expiresAt;
      final expiresAtMs = data['expiresAtMs'];
      if (expiresAtMs is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
      } else {
        // fallback if you haven’t deployed the new function yet
        expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      }

      setState(() {
        _token = token;
        _expiresInSeconds = expiresIn;
        _expiresAt = expiresAt;

        final diff = expiresAt!.difference(DateTime.now()).inSeconds;
        _secondsLeft = diff < 0 ? 0 : diff;
      });

      // ✅ IMPORTANT: reschedule auto refresh AFTER every new token
      _scheduleAutoRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate QR: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + safeBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
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
                      'This QR refreshes automatically for security',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF9CA3AF),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // QR CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
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
                          if (_token.isNotEmpty && !_loading)
                            QrImageView(
                              data: _token,
                              version: QrVersions.auto,
                              size: (constraints.maxWidth - 48).clamp(220, 280),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF2E3440),
                            )
                          else
                            const SizedBox(
                              height: 240,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF88C999),
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Countdown
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Expires in: $_secondsLeft s',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Token text (optional)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _token.isEmpty ? 'Generating...' : _token,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Manual refresh
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _loading ? null : _createNewQrToken,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E3440),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(_loading ? 'Refreshing...' : 'Refresh QR'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // INFO
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
                            '1. Show this QR to the kiosk scanner\n'
                            '2. QR is valid for a short time\n'
                            '3. Pour your used cooking oil\n'
                            '4. Points are recorded automatically',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E40AF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
