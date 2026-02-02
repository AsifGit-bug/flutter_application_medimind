import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medicine_model.dart';
import 'add_medicine_page.dart';

class MedicineDetailPage extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback? onDelete;
  final Function(Medicine)? onUpdate;
  final String userId;
  final bool isReadOnly;

  const MedicineDetailPage({
    super.key,
    required this.medicine,
    this.onDelete,
    this.onUpdate,
    required this.userId,
    this.isReadOnly = false,
  });

  @override
  State<MedicineDetailPage> createState() => _MedicineDetailPageState();
}

class _MedicineDetailPageState extends State<MedicineDetailPage> {
  // Theme Colors
  final Color primaryBlue = const Color(0xFF1565C0);
  final Color darkBlue = const Color(0xFF1976D2);
  final Color bgWithBlueTint = const Color(0xFFF0F4F8);

  void _navigateToEdit() async {
    if (widget.isReadOnly) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMedicinePage(medicine: widget.medicine, userId: widget.userId),
      ),
    );

    if (result != null && result is Medicine && widget.onUpdate != null) {
      widget.onUpdate!(result);
      setState(() {}); // Rebuild local view
    }
  }

  void _confirmDelete() {
    if (widget.isReadOnly || widget.onDelete == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Archive Medicine?"),
        content: const Text(
          "This will stop tracking the medicine but keep its dose history in your records.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete!(); // Trigger archive callback
            },
            child: const Text("Archive", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Hero Header AppBar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: theme.primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: widget.isReadOnly
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: _navigateToEdit,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                      onPressed: _confirmDelete,
                    ),
                  ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.medicine.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: 0.2,
                      child: Icon(
                        _getIconForType(widget.medicine.type),
                        size: 120,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary Info Card
                  _buildPrimaryCard(theme, isDark),
                  const SizedBox(height: 24),

                  // Schedule & Instructions
                  _buildSectionTitle(theme, "Medication Guide"),
                  const SizedBox(height: 12),
                  _buildGuideCard(theme, isDark),
                  const SizedBox(height: 24),

                  // History Section
                  _buildSectionTitle(theme, "Adherence History"),
                  const SizedBox(height: 12),
                  _buildHistoryCard(theme, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.textTheme.bodyLarge?.color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPrimaryCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernStat(
                theme,
                Icons.speed,
                "Dosage",
                widget.medicine.dosage,
              ),
              _buildModernStat(
                theme,
                Icons.calendar_month,
                "Frequency",
                widget.medicine.frequency,
              ),
              _buildModernStat(
                theme,
                Icons.category_outlined,
                "Type",
                widget.medicine.type,
              ),
            ],
          ),
          if (widget.medicine.frequency == 'Weekly') ...[
            const Divider(height: 40),
            Text(
              "Scheduled Days",
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((
                day,
              ) {
                bool isSelected = widget.medicine.weeklyDays.any(
                  (d) => d.startsWith(day),
                );
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.dividerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernStat(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(icon, color: theme.primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildGuideCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _buildGuideRow(
            theme,
            Icons.restaurant,
            "Meal Timing",
            widget.medicine.mealInstruction,
          ),
          const Divider(height: 32),
          _buildGuideRow(
            theme,
            Icons.info_outline,
            "Instructions",
            widget.medicine.instructions.isEmpty
                ? "No special instructions"
                : widget.medicine.instructions,
          ),
          const Divider(height: 32),
          _buildGuideRow(
            theme,
            Icons.alarm,
            "Scheduled Times",
            widget.medicine.scheduleTimes.isEmpty
                ? DateFormat('h:mm a').format(widget.medicine.time)
                : widget.medicine.scheduleTimes
                      .map((t) => DateFormat('h:mm a').format(t))
                      .join(", "),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(ThemeData theme, bool isDark) {
    final history = widget.medicine.doseHistory.reversed.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "No records found yet",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat(
                          'EEEE, MMM d • h:mm a',
                        ).format(history[index]),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'capsule':
        return Icons.medication;
      case 'tablet':
        return Icons.circle;
      case 'syrup':
        return Icons.water_drop;
      case 'injection':
        return Icons.vaccines;
      default:
        return Icons.medical_services;
    }
  }
}
