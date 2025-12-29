// lib/screens/deposit_detail_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class DepositDetailScreen extends StatelessWidget {
  final String depositId;
  const DepositDetailScreen({super.key, required this.depositId});

  String fmt(Timestamp? ts) {
    if (ts == null) return 'Unknown';
    return DateFormat('dd MMM yyyy, h:mm a').format(ts.toDate().toLocal());
  }

  String fmtFileTime(Timestamp? ts) {
    if (ts == null) return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return DateFormat('yyyyMMdd_HHmmss').format(ts.toDate().toLocal());
  }

  Future<void> _downloadReceiptPdf({
    required BuildContext context,
    required String kioskName,
    required String kioskId,
    required double weightGram,
    required int points,
    required Timestamp? ts,
    required String userId,
  }) async {
    try {
      // 1) Build PDF
      final pdf = pw.Document();

      final dtText = fmt(ts);
      final kg = weightGram / 1000.0;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) {
            pw.Widget lineItem(String label, String value) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(label,
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        )),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Text(
                        value,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'UCO Deposit Receipt',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Receipt ID: $depositId',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),

                // Summary Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        '${kg.toStringAsFixed(3)} kg',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${weightGram.toStringAsFixed(2)} g',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Divider(color: PdfColors.grey300),

                      lineItem('Kiosk', kioskName.isNotEmpty ? kioskName : kioskId),
                      lineItem('Points Earned', '+$points'),
                      lineItem('Timestamp', dtText),
                      lineItem('Collected by (userId)', userId.isEmpty ? '-' : userId),
                    ],
                  ),
                ),

                pw.Spacer(),
                pw.Text(
                  'Thank you for recycling used cooking oil responsibly.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );

      // 2) Save file to app documents
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'UCO_Receipt_${fmtFileTime(ts)}_$depositId.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      // 3) Open it
      await OpenFilex.open(file.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt saved: $filename')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate receipt: $e')),
        );
      }
    }
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
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF88C999)),
              );
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('Deposit not found'));
            }

            final data = snap.data!.data()! as Map<String, dynamic>;
            final kioskId = data['kioskId'] ?? 'Unknown';

            final weight =
                (data['weight'] is int) ? (data['weight'] as int).toDouble() : (data['weight'] ?? 0.0);
            final points = data['points'] ?? (weight / 10).round();
            final ts = data['timestamp'] as Timestamp?;
            final userId = data['userId'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('kiosks').doc(kioskId).get(),
              builder: (context, kioskSnap) {
                Map<String, dynamic>? kioskData;
                if (kioskSnap.hasData && kioskSnap.data!.exists) {
                  kioskData = kioskSnap.data!.data() as Map<String, dynamic>;
                }

                final kioskName =
                    kioskData != null ? (kioskData['name'] ?? kioskId).toString() : kioskId;

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
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                                  const Text('Kiosk', style: TextStyle(color: Color(0xFF9CA3AF))),
                                  const SizedBox(height: 6),
                                  Text(
                                    kioskName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Points', style: TextStyle(color: Color(0xFF9CA3AF))),
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
                          const Text('Timestamp', style: TextStyle(color: Color(0xFF9CA3AF))),
                          const SizedBox(height: 6),
                          Text(fmt(ts), style: const TextStyle(color: Color(0xFF6B7280))),
                          const SizedBox(height: 12),
                          const Text('Collected by (userId)', style: TextStyle(color: Color(0xFF9CA3AF))),
                          const SizedBox(height: 6),
                          Text(userId, style: const TextStyle(color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // ✅ Download Receipt button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _downloadReceiptPdf(
                            context: context,
                            kioskName: kioskName,
                            kioskId: kioskId,
                            weightGram: weight.toDouble(),
                            points: points is int ? points : int.tryParse(points.toString()) ?? 0,
                            ts: ts,
                            userId: userId.toString(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF88C999),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Download receipt',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
