import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../config/translations.dart';
import '../models/reading.dart';

class PulseAnalysisScreen extends StatefulWidget {
  const PulseAnalysisScreen({super.key});

  @override
  State<PulseAnalysisScreen> createState() => _PulseAnalysisScreenState();
}

class _PulseAnalysisScreenState extends State<PulseAnalysisScreen> {
  bool _isLoading = true;
  List<Reading> _readings = [];
  double _min = 0;
  double _max = 0;
  double _avg = 0;

  @override
  void initState() {
    super.initState();
    _fetchPulseData();
  }

  Future<void> _fetchPulseData() async {
    final client = Supabase.instance.client;
    try {
      final data = await client.from('readings').select().order('created_at', ascending: true);
      // Ensure your Reading.fromMap correctly handles 'created_at'
      final List<Reading> loaded = (data as List).map((e) => Reading.fromMap(e)).toList();

      if (loaded.isNotEmpty) {
        final pulses = loaded.map((e) => e.pulse.toDouble()).toList();
        _min = pulses.reduce((curr, next) => curr < next ? curr : next);
        _max = pulses.reduce((curr, next) => curr > next ? curr : next);
        _avg = pulses.reduce((a, b) => a + b) / pulses.length;
      }

      if (mounted) {
        setState(() {
          _readings = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white70 : Colors.grey.shade800;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.get('pulse_title'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _readings.isEmpty
              ? Center(child: Text(AppTranslations.get('stats_no_data')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 1. STATS CARDS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(AppTranslations.get('pulse_min'), "${_min.toInt()}", Colors.blue),
                          _buildStatCard(AppTranslations.get('pulse_avg'), "${_avg.toInt()}", Colors.orange),
                          _buildStatCard(AppTranslations.get('pulse_max'), "${_max.toInt()}", Colors.red),
                        ],
                      ),
                      
                      const SizedBox(height: 40),

                      // 2. CHART
                      Container(
                        height: 350, 
                        padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,5))],
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true, 
                              drawVerticalLine: false,
                              horizontalInterval: 20,
                              getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true, 
                                  interval: 20,
                                  reservedSize: 35,
                                  getTitlesWidget: (val, meta) => Text("${val.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: _calculateInterval(),
                                  getTitlesWidget: (val, meta) {
                                    int index = val.toInt();
                                    if (index >= 0 && index < _readings.length) {
                                      // --- FIX: Accessing 'createdAt' correctly ---
                                      // We check if it is already a DateTime or needs parsing
                                      final rawDate = _readings[index].createdAt; 
                                      // (Assuming your model stores it as DateTime. If String, use DateTime.parse(rawDate))
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          DateFormat('MM/dd').format(rawDate), 
                                          style: const TextStyle(fontSize: 10, color: Colors.grey)
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minY: 40,
                            maxY: 140,
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: 100, color: Colors.red.withOpacity(0.5), strokeWidth: 1, dashArray: [5, 5], 
                                  label: HorizontalLineLabel(show: true, style: const TextStyle(color: Colors.red, fontSize: 10), alignment: Alignment.topRight, labelResolver: (l) => "> 100"),
                                ),
                                HorizontalLine(
                                  y: 60, color: Colors.blue.withOpacity(0.5), strokeWidth: 1, dashArray: [5, 5], 
                                  label: HorizontalLineLabel(show: true, style: const TextStyle(color: Colors.blue, fontSize: 10), alignment: Alignment.bottomRight, labelResolver: (l) => "< 60"),
                                ),
                              ],
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _readings.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.pulse.toDouble())).toList(),
                                isCurved: true,
                                color: Colors.redAccent,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true, 
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.redAccent.withOpacity(0.4),
                                      Colors.redAccent.withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 5),
                          Text(AppTranslations.get('pulse_label'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  double _calculateInterval() {
    if (_readings.length < 5) return 1;
    return (_readings.length / 5).floorToDouble();
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}