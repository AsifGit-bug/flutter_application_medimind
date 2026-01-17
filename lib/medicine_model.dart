class Medicine {
  String id;
  String name;
  String dosage;
  String frequency;
  DateTime time; // The daily scheduled time
  List<DateTime> doseHistory; // Log of when doses were taken
  String type; // e.g., Pill, Syrup, Injection
  String instructions; // e.g., Take with food

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    this.doseHistory = const [],
    this.type = 'Pill',
    this.instructions = 'Take as prescribed',
  });
}
