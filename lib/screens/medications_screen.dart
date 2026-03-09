import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../config/translations.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _meds = [];
  bool _isLoading = true;
  
  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() => _isLoading = true);
    final client = Supabase.instance.client;

    try {
      final medsData = await client.from('medications').select().order('created_at');
      
      final checksData = await client
          .from('medication_checks')
          .select()
          .eq('check_date', _todayStr);

      final List<dynamic> checksList = checksData as List;
      
      final loadedMeds = (medsData as List).map((m) {
        final med = Medication.fromMap(m);
        final count = checksList.where((c) => c['medication_id'] == med.id).length;
        med.takenCount = count;
        return med;
      }).toList();

      if (mounted) setState(() { _meds = loadedMeds; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REUSABLE DIALOG: Handles both ADD and EDIT ---
  Future<void> _showMedicationDialog({Medication? existingMed}) async {
    final bool isEditing = existingMed != null;
    
    // Initialize Controllers
    final nameCtrl = TextEditingController(text: isEditing ? existingMed.name : '');
    final doseCtrl = TextEditingController(text: isEditing ? existingMed.dosage : '');
    
    // Initialize Frequency & Times
    int frequency = isEditing ? existingMed.frequency : 1;
    List<TimeOfDay> reminderTimes = [];

    if (isEditing && existingMed.reminderTimes.isNotEmpty) {
      reminderTimes = existingMed.reminderTimes.map((t) {
        final parts = t.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }).toList();
    } else {
      reminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
    }

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside while saving
      builder: (ctx) { // We still name this 'ctx' but we won't use it for popping
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? "Edit Medication" : AppTranslations.get('meds_add')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: InputDecoration(labelText: AppTranslations.get('meds_name'))),
                    TextField(controller: doseCtrl, decoration: InputDecoration(labelText: AppTranslations.get('meds_dosage'))),
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Text(AppTranslations.get('meds_freq_label')),
                        const Spacer(),
                        DropdownButton<int>(
                          value: frequency,
                          items: [1, 2, 3, 4].map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                frequency = val;
                                if (reminderTimes.length < frequency) {
                                  while (reminderTimes.length < frequency) {
                                    reminderTimes.add(const TimeOfDay(hour: 8, minute: 0));
                                  }
                                } else {
                                  reminderTimes = reminderTimes.sublist(0, frequency);
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Text("Reminder Times:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    
                    ...List.generate(frequency, (index) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text("Dose ${index + 1}"),
                        trailing: TextButton(
                          child: Text(reminderTimes[index].format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: reminderTimes[index]);
                            if (picked != null) {
                              setDialogState(() {
                                reminderTimes[index] = picked;
                              });
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                // 1. USE 'ctx' HERE IS OKAY (It's immediate)
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: Text(AppTranslations.get('cancel_btn'))
                ),
                
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isNotEmpty) {
                      // Format times
                      String timesString = reminderTimes.map((t) => "${t.hour}:${t.minute.toString().padLeft(2,'0')}").join(",");
                      final client = Supabase.instance.client;
                      final userId = client.auth.currentUser!.id;

                      if (isEditing) {
                        await client.from('medications').update({
                          'name': nameCtrl.text,
                          'dosage': doseCtrl.text,
                          'frequency': frequency,
                          'reminder_times': timesString,
                        }).eq('id', existingMed.id);
                        List<String> timeList = timesString.split(',');
                        await NotificationService.scheduleMedicationReminders(existingMed.id, nameCtrl.text, timeList);
                      } else {
                        final data = await client.from('medications').insert({
                          'user_id': userId,
                          'name': nameCtrl.text,
                          'dosage': doseCtrl.text,
                          'frequency': frequency,
                          'reminder_times': timesString,
                        }).select();

                        if (data.isNotEmpty) {
                           final newMed = data[0];
                           List<String> timeList = timesString.split(',');
                           await NotificationService.scheduleMedicationReminders(newMed['id'], newMed['name'], timeList);
                        }
                      }

                      // --- THE FIX IS HERE ---
                      if (mounted) {
                        // 2. Use 'Navigator.of(context).pop()' instead of 'Navigator.pop(ctx)'
                        // 'context' refers to the Screen, which is stable.
                        Navigator.of(context).pop(); 
                        _fetchMedications();
                      }
                    }
                  },
                  child: Text(AppTranslations.get('save_btn')),
                )
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _takeDose(Medication med) async {
    if (med.takenCount >= med.frequency) return; 
    setState(() { med.takenCount++; }); 

    try {
      await Supabase.instance.client.from('medication_checks').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'medication_id': med.id,
        'check_date': _todayStr,
      });
    } catch (e) {
      setState(() { med.takenCount--; }); 
    }
  }

  Future<void> _undoDose(Medication med) async {
    if (med.takenCount <= 0) return;
    setState(() { med.takenCount--; });

    try {
      final response = await Supabase.instance.client
          .from('medication_checks')
          .select('id')
          .eq('medication_id', med.id)
          .eq('check_date', _todayStr)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      
      await Supabase.instance.client.from('medication_checks').delete().eq('id', response['id']);
    } catch (e) {
      setState(() { med.takenCount++; }); 
    }
  }
  
  Future<void> _deleteMed(Medication med) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Delete this medication?"),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
           TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes", style: TextStyle(color: Colors.red))),
        ]
      )
    );
    
    if (confirm == true) {
       await NotificationService.scheduleMedicationReminders(med.id, med.name, []); // Cancel alarms
       await Supabase.instance.client.from('medications').delete().eq('id', med.id);
       _fetchMedications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.get('meds_title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMedicationDialog(), // Call with null for ADD
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _meds.isEmpty 
          ? Center(child: Text(AppTranslations.get('meds_empty'), style: const TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _meds.length,
              itemBuilder: (ctx, i) {
                final med = _meds[i];
                final isDone = med.isCompleted;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _takeDose(med),       
                    onLongPress: () => _undoDose(med), 
                    
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // 1. Icon
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: isDone ? Colors.green.shade100 : Colors.blue.shade50,
                            child: Icon(
                              isDone ? Icons.check : Icons.medication, 
                              color: isDone ? Colors.green : Colors.blue
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // 2. Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med.name, style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? Colors.grey : null
                                )),
                                if (med.dosage != null && med.dosage!.isNotEmpty)
                                  Text(med.dosage!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                
                                if (med.reminderTimes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.alarm, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(med.reminderTimes.join(", "), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  )
                              ],
                            ),
                          ),
                          
                          // 3. Counter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDone ? Colors.green : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${med.takenCount}/${med.frequency}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDone ? Colors.white : Colors.black87
                              ),
                            ),
                          ),

                          // 4. ACTION BUTTONS (Edit & Delete)
                          // EDIT
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                            tooltip: "Edit",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(), // tighten layout
                            onPressed: () => _showMedicationDialog(existingMed: med),
                          ),
                          const SizedBox(width: 10),
                          // DELETE
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: "Delete",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteMed(med),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}