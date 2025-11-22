// lib/screens/monthly_chart_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlyChartScreen extends StatelessWidget {
  final String userId;
  const MonthlyChartScreen({super.key, required this.userId});

  Future<Map<String, double>> _fetchMonthlyTotals() async {
    final now = DateTime.now();
    final firstOfYear = DateTime(now.year, 1, 1);
    final q = await FirebaseFirestore.instance
        .collection('deposits')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(firstOfYear))
        .get();

    final Map<int, double> map = {};
    for (var d in q.docs) {
      final data = d.data();
      final ts = (data['timestamp'] as Timestamp?)?.toDate().toLocal();
      if (ts == null) continue;
      final m = ts.month;
      final w = (data['weight'] is int) ? (data['weight'] as int).toDouble() : (data['weight'] ?? 0.0);
      map[m] = (map[m] ?? 0) + w;
    }
    // convert to strings monthName -> kg value
    final Map<String, double> out = {};
    for (int m = 1; m <= 12; m++) {
      final name = DateFormat.MMM().format(DateTime(0, m));
      out[name] = (map[m] ?? 0) / 1000.0; // kg
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Stats'), backgroundColor: const Color(0xFF2E3440)),
      body: FutureBuilder<Map<String, double>>(
        future: _fetchMonthlyTotals(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF88C999)));
          final data = snap.data!;
          final items = data.entries.toList();
          // Minimal chart using fl_chart
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (items.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b) + 1),
                    barGroups: List.generate(items.length, (i) {
                      return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: items[i].value)]);
                    }),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        final label = idx >= 0 && idx < items.length ? items[idx].key : '';
                        return Text(label, style: const TextStyle(fontSize: 10));
                      })),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    ),
                  )),
                ),
                const SizedBox(height: 12),
                Text('Total this year: ${data.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)} kg'),
              ],
            ),
          );
        },
      ),
    );
  }
}
