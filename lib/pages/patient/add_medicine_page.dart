import 'package:flutter/material.dart';

import '../../models/medicine_model.dart';
import '../../services/database_service.dart';

class AddMedicinePage extends StatefulWidget {
  final Medicine? medicine;
  final String userId; // New required field
  const AddMedicinePage({super.key, this.medicine, required this.userId});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController =
      TextEditingController(); // Strength
  bool _isSaving = false;

  // State
  String _frequency = 'Daily';
  String _type = 'Pill';
  String _mealInstruction = 'None';
  List<TimeOfDay> _selectedTimes = [TimeOfDay.now()]; // Support multiple times

  // Options
  final List<String> _frequencies = [
    'Daily',
    'Twice a day',
    'Thrice a day',
    'Weekly',
    'As needed',
  ];
  final List<String> _types = [
    'Pill',
    'Syrup',
    'Injection',
    'Drops',
    'Inhaler',
    'Powder',
    'Other',
  ];
  final List<String> _mealOptions = [
    'Before Meal',
    'After Meal',
    'Empty Stomach',
    'Not Important',
    'None', // Default
  ];

  // Colors
  final Color primaryBlue = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage;
      _frequency = widget.medicine!.frequency;
      _type = widget.medicine!.type;
      _mealInstruction = widget.medicine!.mealInstruction;

      // Load times
      if (widget.medicine!.scheduleTimes.isNotEmpty) {
        _selectedTimes = widget.medicine!.scheduleTimes
            .map((dt) => TimeOfDay.fromDateTime(dt))
            .toList();
      } else {
        _selectedTimes = [TimeOfDay.fromDateTime(widget.medicine!.time)];
      }
    }
    _updateTimeListBasedOnFrequency(); // Ensure sync
  }

  void _updateTimeListBasedOnFrequency() {
    int count = 1;
    if (_frequency == 'Twice a day') count = 2;
    if (_frequency == 'Thrice a day') count = 3;

    if (_selectedTimes.length < count) {
      // Add defaults if needed
      while (_selectedTimes.length < count) {
        _selectedTimes.add(const TimeOfDay(hour: 8, minute: 0));
      }
    } else if (_selectedTimes.length > count) {
      // Truncate
      _selectedTimes = _selectedTimes.sublist(0, count);
    }
    // "As needed" or "Weekly" usually 1 time reference or none? Let's keep 1 for Weekly.
    // "As needed" maybe no time? But for simplicity let's keep 1 reference time.
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  void _saveMedicine() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      // Convert TimeODays to DateTimes (using today as base)
      final now = DateTime.now();
      List<DateTime> finalTimes = _selectedTimes.map((tod) {
        return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
      }).toList();

      final isEditing = widget.medicine != null;
      final medicine = Medicine(
        id: isEditing ? widget.medicine!.id : '',
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: _frequency,
        time: finalTimes[0], // Primary time
        scheduleTimes: finalTimes,
        doseHistory: isEditing ? widget.medicine!.doseHistory : [],
        type: _type,
        instructions:
            _mealInstruction, // Using meal instruction as main instruction for now or we can concat
        mealInstruction: _mealInstruction,
      );

      try {
        final db = DatabaseService();
        await db.addMedicine(medicine, widget.userId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.medicine != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? "Edit Medicine" : "Add Medicine"),
        centerTitle: true,
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              _buildSectionTitle("Medicine Details"),
              _buildTextField(
                controller: _nameController,
                label: "Medicine Name",
                icon: Icons.medication,
                hint: "e.g. Paracetamol",
              ),
              const SizedBox(height: 16),

              // Type Selector
              _buildDropdown(
                label: "Medicine Type",
                value: _type,
                items: _types,
                icon: Icons.category,
                onChanged: (val) => setState(() => _type = val!),
              ),
              const SizedBox(height: 16),

              // Strength / Dosage
              _buildTextField(
                controller: _dosageController,
                label: "Strength / Amount",
                icon: Icons.local_pharmacy,
                hint: "e.g. 500mg, 5ml",
              ),
              const SizedBox(height: 24),

              // Scheduling
              _buildSectionTitle("Scheduling"),
              _buildDropdown(
                label: "Frequency",
                value: _frequency,
                items: _frequencies,
                icon: Icons.repeat,
                onChanged: (val) {
                  setState(() {
                    _frequency = val!;
                    _updateTimeListBasedOnFrequency();
                  });
                },
              ),
              const SizedBox(height: 16),

              // Time Pickers (Dynamic List)
              ...List.generate(_selectedTimes.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _selectTime(context, index),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _selectedTimes[index].format(context),
                        ),
                        decoration: _inputDecoration(
                          "Dose ${index + 1} Time",
                          Icons.access_time,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Meal Instruction
              _buildDropdown(
                label: "Meal Instruction",
                value: _mealInstruction,
                items: _mealOptions,
                icon: Icons.restaurant,
                onChanged: (val) => setState(() => _mealInstruction = val!),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isEditing ? "Update Medicine" : "Save Medicine",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: _inputDecoration(hint, icon),
          validator: (val) => val!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: _inputDecoration("", icon),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.grey.withValues(alpha: 0.1)
        : const Color(0xFFF5F9FC);
    final hintColor = isDark ? Colors.grey[500] : const Color(0xFFB0BEC5);

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: hintColor),
      hintStyle: TextStyle(color: hintColor),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
    );
  }
}
