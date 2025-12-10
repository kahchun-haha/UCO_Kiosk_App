// lib/screens/monthly_chart_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlyChartScreen extends StatelessWidget {
  final String userId;
  const MonthlyChartScreen({super.key, required this.userId});

  Future<List<double>> _fetchMonthlyTotals() async {
    final now = DateTime.now();
    final firstOfYear = DateTime(now.year, 1, 1);

    final q = await FirebaseFirestore.instance
        .collection('deposits')
        .where('userId', isEqualTo: userId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstOfYear))
        .get();

    // 12 months, index 0 = Jan, 11 = Dec, values in kg
    final List<double> totals = List.filled(12, 0.0);

    for (var d in q.docs) {
      final data = d.data();
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) continue;

      final weightRaw = data['weight'] ?? 0;
      final double weightGrams = weightRaw is int
          ? weightRaw.toDouble()
          : (weightRaw is double ? weightRaw : 0.0);

      final monthIndex = ts.month - 1; // 0–11
      if (monthIndex >= 0 && monthIndex < 12) {
        totals[monthIndex] += weightGrams / 1000.0; // convert to kg
      }
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF8F9FA);
    const primaryColor = Color(0xFF2E3440);
    const accentColor = Color(0xFF88C999);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryColor),
        title: const Text(
          'Monthly Stats',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<List<double>>(
        future: _fetchMonthlyTotals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: accentColor,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'No data available yet.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
              ),
            );
          }

          final totals = snapshot.data!;
          final totalYear = totals.fold<double>(0.0, (a, b) => a + b);
          final maxY = totals.fold<double>(0.0, (a, b) => a > b ? a : b);
          final safeMaxY = maxY == 0 ? 1.0 : (maxY * 1.3); // little headroom

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Monthly Recycling',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('yyyy').format(DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Total this year: ${totalYear.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 260,
                        child: BarChart(
                          BarChartData(
                            backgroundColor: Colors.white,
                            maxY: safeMaxY,
                            barTouchData: BarTouchData(
                              enabled: false, // no tooltips → avoids API issues
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawHorizontalLine: true,
                              drawVerticalLine: false,
                              horizontalInterval: safeMaxY / 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: const Color(0xFFE5E7EB),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(
                              show: false,
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: safeMaxY / 4,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 24,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 || idx > 11) {
                                      return const SizedBox.shrink();
                                    }
                                    final label = DateFormat.MMM()
                                        .format(DateTime(0, idx + 1));
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: List.generate(12, (index) {
                              final value = totals[index];
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: value,
                                    width: 10,
                                    borderRadius: BorderRadius.circular(8),
                                    color: accentColor,
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Tip: keep recycling regularly to see your bars grow month by month.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
