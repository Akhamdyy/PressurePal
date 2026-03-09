import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';
import '../widgets/health_chart.dart'; 
import '../widgets/stats_card.dart';
import '../services/pdf_service.dart';
import '../models/reading.dart';
import '../services/notification_service.dart';
import '../config/translations.dart';
import '../screens/settings_screen.dart';
import '../services/export_service.dart';
import '../screens/medications_screen.dart';
import '../screens/advanced_stats_screen.dart';
import '../screens/pulse_analysis_screen.dart';
import '../screens/ai_doctor_screen.dart';
import '../services/ocr_service.dart'; 
import '../services/voice_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final sysCtrl = TextEditingController();
  final diaCtrl = TextEditingController();
  final pulseCtrl = TextEditingController();
  
  DateTime? _selectedDate; 
  bool _medicationTaken = false; 
  int _chartFilterDays = 7; 
  bool _isScanning = false; 

  final _readingsStream = Supabase.instance.client
      .from('readings')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  @override
  void initState() {
    super.initState();
    NotificationService.scheduleDailyNotification(9, 0);
    NotificationService.scheduleDailyNotification(15, 0);
    NotificationService.scheduleDailyNotification(21, 0);
  }

  // --- VOICE LOGIC ---
  Future<void> _scanFromVoice(StateSetter setSheetState) async {
    setSheetState(() => _isScanning = true);
    
    try {
      final result = await VoiceService.listenForBloodPressure();

      if (result != null) {
        // Auto-fill
        sysCtrl.text = result['sys'].toString();
        diaCtrl.text = result['dia'].toString();
        if (result['pulse'] != 0) {
          pulseCtrl.text = result['pulse'].toString();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('voice_success')), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                  content: Text("⚠️ Try saying: 120 80 70 (Pressure then Pulse)"), 
                  backgroundColor: Colors.orange
                ),
          );
        }
      }
    } catch (e) {
      debugPrint("Voice error: $e");
    } finally {
      setSheetState(() => _isScanning = false);
    }
  }
  // --- CAMERA SCAN LOGIC (With Translations) ---
  Future<void> _scanFromCamera(StateSetter setSheetState) async {
    setSheetState(() => _isScanning = true);
    
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final result = await OcrService.scanImage();

      if (result != null) {
        // Auto-fill the controllers
        sysCtrl.text = result['sys'].toString();
        diaCtrl.text = result['dia'].toString();
        if (result['pulse'] != 0) {
          pulseCtrl.text = result['pulse'].toString();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.get('scan_success')), // <--- Translated
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.get('scan_error')), // <--- Translated
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Scan error: $e");
    } finally {
      setSheetState(() => _isScanning = false);
    }
  }
  // -----------------------------

  void _showExportSheet(List<Reading> readings) {
    if (readings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export!")));
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Export Report", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
            ),
            const SizedBox(height: 20),
            
            // OPTION 1: PDF
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("Share as PDF"),
              subtitle: const Text("Best for printing or email"),
              onTap: () async {
                Navigator.pop(context);
                await PdfService().shareReport(readings);
              },
            ),
            
            // OPTION 2: CSV
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text("Share as Excel (CSV)"),
              subtitle: const Text("Best for doctors analysis"),
              onTap: () async {
                Navigator.pop(context);
                await ExportService().shareCSV(readings);
              },
            ),
            
            // OPTION 3: Text
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text("Share Summary"),
              subtitle: const Text("Quick text for WhatsApp"),
              onTap: () async {
                Navigator.pop(context);
                await ExportService().shareTextSummary(readings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveReading({int? id}) async {
    if (sysCtrl.text.isEmpty || diaCtrl.text.isEmpty || pulseCtrl.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('validation_error'))));
       return;
    }
    final sys = int.tryParse(sysCtrl.text);
    final dia = int.tryParse(diaCtrl.text);
    final pulse = int.tryParse(pulseCtrl.text);

    if (sys == null || dia == null || pulse == null) return;

    if (sys > 300 || dia > 200 || pulse > 250) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('validation_high')), backgroundColor: Colors.orange),
      );
      return;
    }

    if (sys < dia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('validation_logic')), backgroundColor: Colors.red),
      );
      return;
    }

    final dateToSave = _selectedDate ?? DateTime.now();
    final hour = dateToSave.hour;
    String period = (hour < 12) ? "Morning" : (hour < 17) ? "Afternoon" : "Evening";

    try {
      final data = {
        'sys': sys, 'dia': dia, 'pulse': pulse, 'period': period,
        'medication': _medicationTaken,
        'created_at': dateToSave.toUtc().toIso8601String(), 
      };

      if (id == null) {
        await Supabase.instance.client.from('readings').insert(data);
      } else {
        await Supabase.instance.client.from('readings').update(data).eq('id', id);
      }
      
      // --- SILENT SMS GUARDIAN LOGIC 🛡️ ---
      if (sys >= 180 || dia >= 110) {
        final prefs = await SharedPreferences.getInstance();
        final emergencyPhone = prefs.getString('emergency_phone');
        
        if (emergencyPhone != null && emergencyPhone.isNotEmpty) {
          final Telephony telephony = Telephony.instance;
          
          // Check/Request Permission
          bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
          
          if (permissionsGranted ?? false) {
            final message = "🚨 HEALTH ALERT: High Blood Pressure detected ($sys/$dia). Please check on the patient immediately.";
            
            // Send silently in background
            await telephony.sendSms(
              to: emergencyPhone,
              message: message,
              statusListener: (SendStatus status) {
                // Optional: Listen for success/fail
                if (status == SendStatus.SENT) {
                  debugPrint("✅ Guardian Alert Sent!");
                }
              },
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🚨 Guardian Alert sent silently via SMS."), 
                  backgroundColor: Colors.redAccent
                ),
              );
            }
          }
        }
      }
      // -------------------------------------

      if (mounted) Navigator.of(context).pop(); 
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _resetForm() {
    sysCtrl.clear(); diaCtrl.clear(); pulseCtrl.clear();
    setState(() { _selectedDate = null; _medicationTaken = false; });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context, initialDate: _selectedDate ?? now, firstDate: DateTime(2024), lastDate: now,
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate ?? now),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  void _showEditSheet(Reading? reading) {
    if (reading != null) {
      sysCtrl.text = reading.sys.toString();
      diaCtrl.text = reading.dia.toString();
      pulseCtrl.text = reading.pulse.toString();
      _selectedDate = reading.createdAt;
      _medicationTaken = reading.medication;
    } else {
      _resetForm();
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => _buildSheetContent(reading?.id, setSheetState),
      ),
    );
  }

  Widget _buildSheetContent(int? id, StateSetter setSheetState) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          // HEADER ROW
          // HEADER ROW with BOTH Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id == null ? AppTranslations.get('add_log') : "Edit Entry", 
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              
              if (id == null)
                Row(
                  children: [
                    // --- MIC BUTTON ---
                    if (!_isScanning)
                      IconButton(
                        onPressed: () => _scanFromVoice(setSheetState),
                        icon: const Icon(Icons.mic, color: Colors.blue, size: 28),
                        tooltip: AppTranslations.get('voice_btn'),
                        style: IconButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1)),
                      ),
                    
                    const SizedBox(width: 12),

                    // --- CAMERA BUTTON ---
                    TextButton.icon(
                      onPressed: _isScanning ? null : () => _scanFromCamera(setSheetState),
                      icon: _isScanning 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.camera_alt, color: Colors.teal),
                      label: Text(
                        _isScanning ? AppTranslations.get('scanning') : AppTranslations.get('scan_btn'), 
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)
                      ),
                      style: TextButton.styleFrom(backgroundColor: Colors.teal.withOpacity(0.1)),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // DATE PICKER
          InkWell(
            onTap: () async { await _pickDate(); setSheetState(() {}); },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.teal),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate == null 
                      ? DateFormat('h:mm a').format(DateTime.now())
                      : DateFormat('MMM d, h:mm a').format(_selectedDate!),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // INPUT FIELDS
          Row(children: [
            Expanded(child: _buildInput(sysCtrl, AppTranslations.get('sys_label'))),
            const SizedBox(width: 15),
            Expanded(child: _buildInput(diaCtrl, AppTranslations.get('dia_label'))),
          ]),
          const SizedBox(height: 15),
          _buildInput(pulseCtrl, AppTranslations.get('pulse_label')),
          const SizedBox(height: 15),
          
          // MEDICATION SWITCH
          SwitchListTile(
            title: Text(AppTranslations.get('medication'), style: const TextStyle(fontWeight: FontWeight.bold)),
            value: _medicationTaken,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (val) => setSheetState(() => _medicationTaken = val),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 25),
          
          // SAVE BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _saveReading(id: id),
              child: Text(AppTranslations.get('save_btn')),
            ),
          ),
          
          // DELETE BUTTON (If editing)
          if (id != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.from('readings').delete().eq('id', id);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('log_deleted')), backgroundColor: Colors.red));
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(AppTranslations.get('delete_btn'), style: const TextStyle(color: Colors.red)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.red.withOpacity(0.05)),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  List<Reading> _filterReadings(List<Reading> allReadings) {
    if (_chartFilterDays == -1) return allReadings; 
    final cutoffDate = DateTime.now().subtract(Duration(days: _chartFilterDays));
    return allReadings.where((r) => r.createdAt.isAfter(cutoffDate)).toList();
  }

  Widget _buildFilterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _filterBtn(AppTranslations.get('filter_7'), 7),     
        const SizedBox(width: 10),
        _filterBtn(AppTranslations.get('filter_30'), 30),   
        const SizedBox(width: 10),
        _filterBtn(AppTranslations.get('filter_all'), -1),  
      ],
    );
  }

  Widget _filterBtn(String label, int days) {
    bool isSelected = _chartFilterDays == days;
    bool isDark = Theme.of(context).brightness == Brightness.dark; 
    return InkWell(
      onTap: () => setState(() => _chartFilterDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
        ),
        child: Text(
          label, 
          style: TextStyle(color: isSelected || isDark ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.get(key);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color shadowColor = isDark ? Colors.black.withOpacity(0.05) : Colors.black.withOpacity(0.1); 

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 10,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/appbar_icon.png', height:35, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Text(AppTranslations.get('app_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
            ],
          ),
          actions: [
            IconButton(
            icon: const Icon(Icons.smart_toy_outlined, size: 28), // Robot Icon
            tooltip: "Ask AI Doctor",
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const AiDoctorScreen())
              );
            },
          ),
            IconButton(
              icon: const Icon(Icons.medication_liquid_rounded, color: Colors.teal),
              tooltip: "Medications",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicationsScreen())),
            ),
            PopupMenuButton<String>(
            icon: const Icon(Icons.analytics_outlined, color: Colors.blue),
            tooltip: "Analysis",
            onSelected: (value) {
              if (value == 'stats') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdvancedStatsScreen()));
              } else if (value == 'pulse') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PulseAnalysisScreen()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                value: 'stats',
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: Colors.purple), 
                    const SizedBox(width: 10), 
                    Text(AppTranslations.get('stats_adv_title')),
                  ],
                ),
              ),
                PopupMenuItem<String>(
                value: 'pulse',
                child: Row(
                  children: [
                    const Icon(Icons.monitor_heart, color: Colors.redAccent), 
                    const SizedBox(width: 10), 
                    Text(AppTranslations.get('pulse_title')),
                  ],
                ),
              ),
            ],
          ),
            IconButton(
              icon: const Icon(Icons.ios_share), // The "Share" icon
              onPressed: () async {
                // Get current data snapshot
                final data = await Supabase.instance.client.from('readings').select().order('created_at', ascending: false);
                final readings = (data as List).map((e) => Reading.fromMap(e)).toList();
                
                // Show the new menu
                _showExportSheet(readings);
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: "Settings",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showEditSheet(null),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(t('add_log'), style: const TextStyle(color: Colors.white)), 
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _readingsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!;
            final readings = data.map((map) => Reading.fromMap(map)).toList();

            if (readings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    Icon(Icons.monitor_heart_outlined, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 20),
                    Text(t('empty_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    Text(t('empty_subtitle'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 30),
                    Icon(Icons.arrow_downward_rounded, color: Theme.of(context).primaryColor, size: 30),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatsCard(readings: readings), 
                  const SizedBox(height: 20),
                  _buildFilterButtons(),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color, 
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: HealthChart(readings: _filterReadings(readings)), 
                  ),
                  const SizedBox(height: 20),
                  Text(t('recent_history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: readings.length,
                    itemBuilder: (context, index) {
                      final r = readings[index];
                      bool isHigh = r.sys > 140 || r.dia > 90;
                      
                      // --- TRANSLATION LOGIC FOR LIST ITEMS ---
                      // 1. Translate Period (Morning/Afternoon/Evening)
                      String periodTranslated = t(r.period.toLowerCase()); // Look up 'morning' etc.
                      
                      // 2. Translate Date (e.g. Dec 19 -> ١٩ ديسمبر)
                      String dateTranslated = DateFormat('d MMM', languageNotifier.value).format(r.createdAt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color, 
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ListTile(
                          onTap: () => _showEditSheet(r),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isHigh ? const Color(0xFFFFEBEE) : const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              "${r.sys}/${r.dia}",
                              style: TextStyle(fontWeight: FontWeight.w800, color: isHigh ? Colors.red : Colors.teal, fontSize: 16),
                            ),
                          ),
                          title: Text(periodTranslated, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.favorite, size: 14, color: Colors.red.shade300),
                                const SizedBox(width: 4),
                                // 3. Translate BPM
                                Text("${r.pulse} ${t('bpm')}  •  $dateTranslated"),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.medication) 
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                  child: const Icon(Icons.medication, color: Colors.green, size: 20),
                                ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));
  }
}