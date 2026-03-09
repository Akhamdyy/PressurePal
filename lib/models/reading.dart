class Reading {
  final int id;
  final int sys;
  final int dia;
  final int pulse;
  final String period;
  final bool medication;
  final DateTime createdAt;

  Reading({
    required this.id,
    required this.sys,
    required this.dia,
    required this.pulse,
    required this.period,
    required this.medication,
    required this.createdAt,
  });

  factory Reading.fromMap(Map<String, dynamic> map) {
    return Reading(
      id: map['id'],
      sys: map['sys'],
      dia: map['dia'],
      pulse: map['pulse'],
      period: map['period'],
      medication: map['medication'] ?? false,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }

  // Helper to convert back to Map (useful for saving later)
  Map<String, dynamic> toMap() {
    return {
      'sys': sys,
      'dia': dia,
      'pulse': pulse,
      'period': period,
      'medication': medication,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}