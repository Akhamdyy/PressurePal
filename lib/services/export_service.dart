import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';

class ExportService {
  
  // 1. Generate and Share CSV (Excel)
  Future<void> shareCSV(List<Reading> readings) async {
    List<List<dynamic>> rows = [];
    
    // Headers
    rows.add([
      "Date",
      "Time",
      "Period",
      "Systolic",
      "Diastolic",
      "Pulse",
      "Medication Taken"
    ]);

    // Data
    for (var r in readings) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(r.createdAt),
        DateFormat('HH:mm').format(r.createdAt),
        r.period,
        r.sys,
        r.dia,
        r.pulse,
        r.medication ? "Yes" : "No"
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    
    // Save to device temp folder
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/bp_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
    final file = File(path);
    await file.writeAsString(csvData);

    // Share it
    await Share.shareXFiles([XFile(path)], text: 'Here is my Blood Pressure Report (Excel/CSV).');
  }

  // 2. Generate Quick Text Summary for WhatsApp
  Future<void> shareTextSummary(List<Reading> readings) async {
    if (readings.isEmpty) return;

    // Calculate Averages
    int avgSys = (readings.map((e) => e.sys).reduce((a, b) => a + b) / readings.length).round();
    int avgDia = (readings.map((e) => e.dia).reduce((a, b) => a + b) / readings.length).round();
    int avgPulse = (readings.map((e) => e.pulse).reduce((a, b) => a + b) / readings.length).round();
    
    String dateRange = "${DateFormat('MMM d').format(readings.last.createdAt)} - ${DateFormat('MMM d').format(readings.first.createdAt)}";

    String summary = """
🩺 *Blood Pressure Report*
📅 $dateRange

📊 *Averages:*
BP: $avgSys/$avgDia mmHg
Pulse: $avgPulse bpm

📝 *Total Readings:* ${readings.length}

Sent from PressurePal
""";

    await Share.share(summary);
  }
}