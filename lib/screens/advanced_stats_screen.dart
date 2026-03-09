import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/translations.dart';
import '../models/reading.dart'; // Ensure you import your Reading model

class AdvancedStatsScreen extends StatefulWidget {
  const AdvancedStatsScreen({super.key});

  @override
  State<AdvancedStatsScreen> createState() => _AdvancedStatsScreenState();
}

class _AdvancedStatsScreenState extends State<AdvancedStatsScreen> {
  bool _isLoading = true;
  // We store the calculated averages here
  Map<String, double>? _morningStats; 
  Map<String, double>? _eveningStats;

  @override
  void initState() {
    super.initState();
    _calculateStatsLocally();
  }

  Future<void> _calculateStatsLocally() async {
    final client = Supabase.instance.client;
    try {
      // 1. Fetch RAW readings directly (We know this works!)
      final data = await client.from('readings').select();
      final List<Reading> allReadings = (data as List).map((e) => Reading.fromMap(e)).toList();

      // 2. Filter Morning & Evening
      final morningList = allReadings.where((r) => r.period == 'Morning').toList();
      final eveningList = allReadings.where((r) => r.period == 'Evening').toList();

      // 3. Calculate Averages Manually
      Map<String, double>? amStats;
      if (morningList.isNotEmpty) {
        double avgSys = morningList.map((e) => e.sys).reduce((a, b) => a + b) / morningList.length;
        double avgDia = morningList.map((e) => e.dia).reduce((a, b) => a + b) / morningList.length;
        amStats = {'avg_sys': avgSys, 'avg_dia': avgDia};
      }

      Map<String, double>? pmStats;
      if (eveningList.isNotEmpty) {
        double avgSys = eveningList.map((e) => e.sys).reduce((a, b) => a + b) / eveningList.length;
        double avgDia = eveningList.map((e) => e.dia).reduce((a, b) => a + b) / eveningList.length;
        pmStats = {'avg_sys': avgSys, 'avg_dia': avgDia};
      }

      if (mounted) {
        setState(() {
          _morningStats = amStats;
          _eveningStats = pmStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Stats Calculation Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String getInsight() {
    // 1. If NO data at all
    if (_morningStats == null && _eveningStats == null) {
      return AppTranslations.get('stats_no_data');
    }
    
    // 2. If Partial Data
    if (_morningStats == null) return "Record Morning BP to see comparison.";
    if (_eveningStats == null) return "Record Evening BP to see comparison.";

    // 3. If We have BOTH
    double amSys = _morningStats!['avg_sys']!;
    double pmSys = _eveningStats!['avg_sys']!;
    
    if (amSys > pmSys + 5) return AppTranslations.get('stats_higher_am');
    if (pmSys > amSys + 5) return AppTranslations.get('stats_higher_pm');
    return AppTranslations.get('stats_balanced');
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white70 : Colors.grey.shade800;

    // Helper to safely get numbers
    double getVal(Map<String, double>? stats, String key) {
      if (stats == null || stats[key] == null) return 0;
      return stats[key]!;
    }
    
    bool hasData = _morningStats != null || _eveningStats != null;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.get('stats_adv_title'))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // INSIGHT CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900]
                        : [Colors.orange.shade50, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.transparent : Colors.orange.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 24),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppTranslations.get('stats_insight'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                            const SizedBox(height: 5),
                            Text(getInsight(), style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                Text(AppTranslations.get('stats_am_pm'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 30),

                // CHART
                if (hasData)
                  Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.2,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 180, 
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 40,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true, 
                                  reservedSize: 30, 
                                  interval: 40,
                                  getTitlesWidget: (val, _) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey))
                                )
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40, 
                                  getTitlesWidget: (val, _) {
                                    final style = TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14);
                                    if (val == 0) return Padding(padding: const EdgeInsets.only(top: 10), child: Text(AppTranslations.get('morning'), style: style));
                                    if (val == 1) return Padding(padding: const EdgeInsets.only(top: 10), child: Text(AppTranslations.get('evening'), style: style));
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              // Morning
                              BarChartGroupData(
                                x: 0, 
                                barRods: [
                                  BarChartRodData(
                                    toY: getVal(_morningStats, 'avg_sys'), 
                                    color: Colors.red, width: 25, 
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: 180, color: Colors.grey.withOpacity(0.05)),
                                  ),
                                  BarChartRodData(
                                    toY: getVal(_morningStats, 'avg_dia'), 
                                    color: Colors.teal, width: 25, 
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: 180, color: Colors.grey.withOpacity(0.05)),
                                  ),
                                ],
                                barsSpace: 10, 
                              ),
                              // Evening
                              BarChartGroupData(
                                x: 1, 
                                barRods: [
                                  BarChartRodData(
                                    toY: getVal(_eveningStats, 'avg_sys'), 
                                    color: Colors.red, width: 25, 
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: 180, color: Colors.grey.withOpacity(0.05)),
                                  ),
                                  BarChartRodData(
                                    toY: getVal(_eveningStats, 'avg_dia'), 
                                    color: Colors.teal, width: 25, 
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: 180, color: Colors.grey.withOpacity(0.05)),
                                  ),
                                ],
                                barsSpace: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legendItem(Colors.red, AppTranslations.get('legend_sys')),
                          const SizedBox(width: 20),
                          _legendItem(Colors.teal, AppTranslations.get('legend_dia')),
                        ],
                      ),
                    ],
                  )
                else
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 50),
                        Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text(AppTranslations.get('stats_no_data'), style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}