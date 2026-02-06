import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/medicine_model.dart';
import '../../services/database_service.dart';

import '../../utils/translations.dart';
import '../../services/notification_service.dart';

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
  List<String> _selectedWeeklyDays = []; // For Weekly/Specific Days frequency
  int _timesPerDay = 1; // For Specific Days: 1, 2, or 3
  final List<String> _timesPerDayOptions = ['Once', 'Twice', 'Thrice'];
  String _currentLanguage = 'en';

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentLanguage = prefs.getString('language') ?? 'en';
      });
    }
  }

  // Options
  final List<String> _frequencies = [
    'Daily',
    'Twice a day',
    'Thrice a day',
    'Specific Days',
    'Weekly',
    'As needed',
  ];
  final List<String> _types = [
    'Pill',
    'Syrup',
    'Injection',
    'Drops',
    'Inhaler',
    'Other',
  ];
  final List<String> _mealOptions = [
    'Before Meal',
    'After Meal',
    'Empty Stomach',
    'Not Important',
    'None', // Default
  ];
  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage;
      _frequency = widget.medicine!.frequency;
      _type = widget.medicine!.type;
      _mealInstruction = widget.medicine!.mealInstruction;
      _selectedWeeklyDays = List.from(widget.medicine!.weeklyDays);

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
    List<TimeOfDay> defaultTimes = [const TimeOfDay(hour: 8, minute: 0)];

    if (_frequency == 'Twice a day') {
      count = 2;
      defaultTimes = [
        const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
        const TimeOfDay(hour: 20, minute: 0), // 8:00 PM
      ];
    } else if (_frequency == 'Thrice a day') {
      count = 3;
      defaultTimes = [
        const TimeOfDay(hour: 7, minute: 0), // 7:00 AM
        const TimeOfDay(hour: 12, minute: 0), // 12:00 PM
        const TimeOfDay(hour: 21, minute: 0), // 9:00 PM
      ];
    } else if (_frequency == 'Specific Days') {
      count = _timesPerDay;
      if (_timesPerDay == 2) {
        defaultTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
      } else if (_timesPerDay == 3) {
        defaultTimes = [
          const TimeOfDay(hour: 7, minute: 0),
          const TimeOfDay(hour: 12, minute: 0),
          const TimeOfDay(hour: 21, minute: 0),
        ];
      }
    }

    // Reset times when frequency changes to use smart defaults
    if (_selectedTimes.length != count) {
      _selectedTimes = defaultTimes.sublist(0, count);
    }
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
      // Check for duplicate times (only for multiple-dose frequencies)
      if (_selectedTimes.length > 1) {
        final timeSet = <String>{};
        for (var time in _selectedTimes) {
          final key = '${time.hour}:${time.minute}';
          if (timeSet.contains(key)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  Translations.get('duplicate_time_error', _currentLanguage),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          timeSet.add(key);
        }
      }

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
        skipHistory: isEditing ? widget.medicine!.skipHistory : [], // Preserved
        missedHistory: isEditing
            ? widget.medicine!.missedHistory
            : [], // Preserved
        type: _type,
        instructions: _mealInstruction,
        mealInstruction: _mealInstruction,
        weeklyDays: _selectedWeeklyDays,
        createdAt: isEditing
            ? widget.medicine!.createdAt
            : DateTime.now(), // Preserved
      );

      try {
        final db = DatabaseService();

        // 1. Check for duplicates (only for new medicines)
        if (!isEditing) {
          final exists = await db.checkMedicineExists(
            widget.userId,
            medicine.name,
            medicine.type,
            medicine.dosage,
          );

          if (exists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("This medicine already exists!"),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => _isSaving = false);
            }
            return;
          }
        }

        if (isEditing) {
          await db.updateMedicine(medicine, widget.userId);
        } else {
          await db.addMedicine(medicine, widget.userId);
        }

        // Reschedule all notifications with grouping (so same-time medicines are together)
        final allMedicines = await db.getMedicines(widget.userId).first;
        await NotificationService().scheduleAllMedicineNotifications(
          allMedicines,
        );

        if (mounted) Navigator.pop(context, medicine);
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

              // Day Selector (show for Weekly or Specific Days)
              if (_frequency == 'Weekly' || _frequency == 'Specific Days') ...[
                const SizedBox(height: 8),
                Text(
                  "Select Days",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _weekDays.map((day) {
                    final isSelected = _selectedWeeklyDays.contains(day);
                    final currentTheme = Theme.of(context);
                    return FilterChip(
                      label: Text(day.substring(0, 3)), // Mon, Tue, etc.
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (_frequency == 'Weekly') {
                            // Weekly: Only one day allowed
                            if (selected) {
                              _selectedWeeklyDays = [day];
                            } else {
                              _selectedWeeklyDays = [];
                            }
                          } else {
                            // Specific Days: Multiple allowed
                            if (selected) {
                              _selectedWeeklyDays.add(day);
                            } else {
                              _selectedWeeklyDays.remove(day);
                            }
                          }
                        });
                      },
                      backgroundColor:
                          currentTheme.brightness == Brightness.dark
                          ? Colors.grey.withValues(alpha: 0.1)
                          : const Color(0xFFF5F9FC),
                      selectedColor: currentTheme.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? currentTheme.primaryColor
                            : currentTheme.textTheme.bodyMedium?.color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? currentTheme.primaryColor
                            : currentTheme.dividerColor,
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Times Per Day selector (only for Specific Days)
              if (_frequency == 'Specific Days') ...[
                Text(
                  "Times Per Day",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _timesPerDayOptions.asMap().entries.map((entry) {
                    final index = entry.key + 1; // 1, 2, or 3
                    final label = entry.value;
                    final isSelected = _timesPerDay == index;
                    final currentTheme = Theme.of(context);
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _timesPerDay = index;
                            _updateTimeListBasedOnFrequency();
                          });
                        }
                      },
                      backgroundColor:
                          currentTheme.brightness == Brightness.dark
                          ? Colors.grey.withValues(alpha: 0.1)
                          : const Color(0xFFF5F9FC),
                      selectedColor: currentTheme.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? currentTheme.primaryColor
                            : currentTheme.textTheme.bodyMedium?.color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? currentTheme.primaryColor
                            : currentTheme.dividerColor,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

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
                    backgroundColor: theme.primaryColor,
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
          value: items.contains(value) ? value : items.first,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(Translations.get(e, 'en')),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: _inputDecoration(
            "",
            icon,
            customIconPath: label == "Medicine Type"
                ? (value == "Pill"
                      ? 'assets/icons/pill.png'
                      : (value == "Syrup"
                            ? 'assets/icons/syrup.png'
                            : (value == "Injection"
                                  ? 'assets/icons/injection.png'
                                  : (value == "Inhaler"
                                        ? 'assets/icons/inhaler.jpg'
                                        : (value == "Drops"
                                              ? 'assets/icons/drops.jpg'
                                              : (value == "Other"
                                                    ? 'assets/icons/other.png'
                                                    : null))))))
                : null,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    String? customIconPath,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.grey.withValues(alpha: 0.1)
        : const Color(0xFFF5F9FC);
    final hintColor = isDark ? Colors.grey[500] : const Color(0xFFB0BEC5);

    Widget? prefix;
    if (customIconPath != null) {
      prefix = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.asset(
          customIconPath,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
      );
    } else {
      prefix = Icon(icon, color: hintColor);
    }

    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
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
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
    );
  }
}
