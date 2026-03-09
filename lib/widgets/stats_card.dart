import 'package:flutter/material.dart';
import '../models/reading.dart';
import '../config/translations.dart'; // Import translation

class StatsCard extends StatelessWidget {
  final List<Reading> readings;

  const StatsCard({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    // Helper
    String t(String key) => AppTranslations.get(key);

    int avgSys = 0;
    int avgDia = 0;
    int avgPulse = 0;

    if (readings.isNotEmpty) {
      // Calculate averages (last 30)
      final recent = readings.take(30).toList();
      avgSys = (recent.map((e) => e.sys).reduce((a, b) => a + b) / recent.length).round();
      avgDia = (recent.map((e) => e.dia).reduce((a, b) => a + b) / recent.length).round();
      avgPulse = (recent.map((e) => e.pulse).reduce((a, b) => a + b) / recent.length).round();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Colors.red.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                t('avg_label'), // --- TRANSLATED: "Average (Last 30)" ---
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(context, avgPulse.toString(), t('pulse_short')), // --- TRANSLATED ---
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatItem(context, avgDia.toString(), t('dia_short')),     // --- TRANSLATED ---
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatItem(context, avgSys.toString(), t('sys_short')),     // --- TRANSLATED ---
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}