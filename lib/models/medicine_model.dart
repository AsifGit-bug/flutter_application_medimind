class Medicine {
  String id;
  String name;
  String dosage;
  String frequency;
  DateTime time; // Kept for backward compat (primary/first dose)
  List<DateTime> scheduleTimes; // List of all daily scheduled times
  List<DateTime> doseHistory; // Log of when doses were taken
  String type; // e.g., Pill, Syrup, Injection
  String instructions; // Generic instructions
  String mealInstruction; // NEW: Before Meal, After Meal, None

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    this.scheduleTimes = const [],
    this.doseHistory = const [],
    this.type = 'Pill',
    this.instructions = 'Take as prescribed',
    this.mealInstruction = 'None',
  });
}
