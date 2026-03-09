import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math'; 
import '../models/reading.dart';
import '../config/translations.dart'; 

class HealthChart extends StatelessWidget {
  final List<Reading> readings;

  const HealthChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.get(key);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color titleColor = isDark ? Colors.white70 : Colors.grey.shade600;
    Color textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final sorted = List<Reading>.from(readings);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // --- YOUR PERFECT SCALING LOGIC (UNCHANGED) ---
    double minY = 60; 
    double maxY = 180; 
    double minX = 0;
    double maxX = 0;

    if (sorted.isNotEmpty) {
      final allSys = sorted.map((e) => e.sys.toDouble()).toList();
      final allDia = sorted.map((e) => e.dia.toDouble()).toList();
      final allValues = [...allSys, ...allDia];

      double dataMin = allValues.reduce(min);
      double dataMax = allValues.reduce(max);

      minY = (dataMin - 10).clamp(0, double.infinity); 
      maxY = (dataMax + 10);
      
      if (maxY < 150) maxY = 150;

      minX = 0;
      maxX = (sorted.length - 1).toDouble();
    }
    // ----------------------------------------------

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('chart_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 20),
        
        AspectRatio(
          aspectRatio: 1.5,
          // --- FIX: ClipRect prevents ANY painting outside the box ---
          child: ClipRect(
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(), // Internal clipping
                minX: minX, maxX: maxX,
                minY: minY, maxY: maxY,

                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 30, 
                      interval: 20, 
                      getTitlesWidget: (val, meta) {
                        if (val < minY || val > maxY) return const SizedBox.shrink();
                        return Text(val.toInt().toString(), style: TextStyle(color: textColor, fontSize: 10));
                      }
                    )
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(y1: 0, y2: 120, color: Colors.green.withOpacity(0.1)),
                    HorizontalRangeAnnotation(y1: 120, y2: 140, color: Colors.orange.withOpacity(0.1)),
                    HorizontalRangeAnnotation(y1: 140, y2: 500, color: Colors.red.withOpacity(0.1)),
                  ],
                ),
                
                lineBarsData: [
                  LineChartBarData(
                    spots: sorted.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.sys.toDouble())).toList(),
                    isCurved: true, color: Colors.red, barWidth: 3, dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: sorted.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.dia.toDouble())).toList(),
                    isCurved: true, color: Colors.teal, barWidth: 3, dotData: const FlDotData(show: false),
                  ),
                ],
                
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => isDark ? Colors.grey.shade800 : Colors.white,
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(s.y.toInt().toString(), TextStyle(color: s.bar.color, fontWeight: FontWeight.bold))).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(Colors.red, t('legend_sys'), isDark),
            const SizedBox(width: 20),
            _legendItem(Colors.teal, t('legend_dia'), isDark),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label, bool isDark) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade600)),
    ]);
  }
}