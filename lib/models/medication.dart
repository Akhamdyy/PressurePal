class Medication {
  final int id;
  final String name;
  final String? dosage;
  final int frequency; 
  int takenCount;      
  final List<String> reminderTimes; // NEW: Stores "09:00", "14:00" etc.

  Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.frequency = 1,
    this.takenCount = 0,
    this.reminderTimes = const [],
  });

  bool get isCompleted => takenCount >= frequency;

  factory Medication.fromMap(Map<String, dynamic> map) {
    // Parse the comma-separated string back into a List
    List<String> times = [];
    if (map['reminder_times'] != null && map['reminder_times'].toString().isNotEmpty) {
      times = map['reminder_times'].toString().split(',');
    }

    return Medication(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      frequency: map['frequency'] ?? 1,
      reminderTimes: times,
    );
  }
}