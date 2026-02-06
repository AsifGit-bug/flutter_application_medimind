import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medicine_model.dart';
import 'add_medicine_page.dart';
import '../../utils/translations.dart';
import '../../utils/medicine_icon_helper.dart';

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
  final String _currentLanguage = 'en';
  late Medicine _medicine;

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
  }

  void _navigateToEdit() async {
    if (widget.isReadOnly) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMedicinePage(medicine: widget.medicine, userId: widget.userId),
      ),
    );

    if (result != null && result is Medicine) {
      setState(() {
        _medicine = result;
      });
      if (widget.onUpdate != null) {
        widget.onUpdate!(result);
      }
      // setState(() {}); // Already called above
    }
  }

  void _confirmDelete() {
    if (widget.isReadOnly || widget.onDelete == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.get('Archive Medicine?', _currentLanguage)),
        content: Text(Translations.get('archive_desc', _currentLanguage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Translations.get('Cancel', _currentLanguage)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete!(); // Trigger archive callback
            },
            child: Text(
              Translations.get('Archive', _currentLanguage),
              style: const TextStyle(color: Colors.red),
            ),
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
                _medicine.name,
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
                      child: getMedicineIconWidget(_medicine.type, size: 120),
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
                  _buildSectionTitle(
                    theme,
                    Translations.get('Medication Guide', _currentLanguage),
                  ),
                  const SizedBox(height: 12),
                  _buildGuideCard(theme, isDark),
                  const SizedBox(height: 24),

                  // History Section
                  _buildSectionTitle(
                    theme,
                    Translations.get('Adherence History', _currentLanguage),
                  ),
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
                Translations.get('Dosage', _currentLanguage),
                _medicine.dosage,
              ),
              _buildModernStat(
                theme,
                Icons.calendar_month,
                Translations.get('Frequency', _currentLanguage),
                Translations.get(_medicine.frequency, _currentLanguage),
              ),
              _buildModernStat(
                theme,
                Icons.category_outlined,
                Translations.get('Type', _currentLanguage),
                Translations.get(_medicine.type, _currentLanguage),
              ),
            ],
          ),
          if (_medicine.frequency == 'Weekly') ...[
            const Divider(height: 40),
            Text(
              Translations.get('Scheduled Days', _currentLanguage),
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((
                day,
              ) {
                bool isSelected = _medicine.weeklyDays.any(
                  (d) => d.startsWith(day),
                );
                return Container(
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
                      color: isSelected
                          ? Colors.white
                          : theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.8,
                            ),
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
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildGuideCard(ThemeData theme, bool isDark) {
    // Build frequency display with days if applicable
    String frequencyDisplay = _medicine.frequency;
    final freq = _medicine.frequency.toLowerCase();
    if ((freq == 'weekly' || freq == 'specific days') &&
        _medicine.weeklyDays.isNotEmpty) {
      final daysAbbrev = _medicine.weeklyDays
          .map((d) => d.substring(0, 3)) // Mon, Tue, etc.
          .join(', ');
      frequencyDisplay = '${_medicine.frequency} ($daysAbbrev)';
    }

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
            Icons.calendar_today,
            Translations.get('Frequency', _currentLanguage),
            frequencyDisplay,
          ),
          const Divider(height: 32),
          _buildGuideRow(
            theme,
            Icons.restaurant,
            Translations.get('Meal Timing', _currentLanguage),
            Translations.get(_medicine.mealInstruction, _currentLanguage),
          ),
          const Divider(height: 32),
          _buildGuideRow(
            theme,
            Icons.alarm,
            Translations.get('Scheduled Times', _currentLanguage),
            _medicine.scheduleTimes.isEmpty
                ? DateFormat('h:mm a').format(_medicine.time)
                : _medicine.scheduleTimes
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
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.9,
                  ),
                  fontSize: 12,
                ),
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
    // 1. Merge all history types
    List<Map<String, dynamic>> allEvents = [];
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 7));

    // Filter Helper
    bool isRecent(DateTime d) => d.isAfter(cutoffDate);

    for (var date in _medicine.doseHistory) {
      if (isRecent(date)) {
        allEvents.add({'time': date, 'status': 'Taken', 'color': Colors.green});
      }
    }
    for (var date in _medicine.skipHistory) {
      if (isRecent(date)) {
        allEvents.add({
          'time': date,
          'status': 'Skipped',
          'color': Colors.amber,
        });
      }
    }
    for (var date in _medicine.missedHistory) {
      if (isRecent(date)) {
        allEvents.add({'time': date, 'status': 'Missed', 'color': Colors.red});
      }
    }

    // 2. Sort descending
    allEvents.sort((a, b) => b['time'].compareTo(a['time']));

    // 3. Calculate Stats (7 Days)
    final total = allEvents.length;
    final takenCount = allEvents.where((e) => e['status'] == 'Taken').length;
    final skippedCount = allEvents
        .where((e) => e['status'] == 'Skipped')
        .length;
    final missedCount = allEvents.where((e) => e['status'] == 'Missed').length;
    final adherenceRate = total > 0 ? (takenCount / total * 100).toInt() : 0;

    return Column(
      children: [
        // Adherence Stats Row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                theme,
                "$adherenceRate%",
                Translations.get('7-Day Adherence', _currentLanguage),
                true,
              ),
              _buildVerticalDivider(theme),
              _buildStatItem(
                theme,
                "$takenCount",
                Translations.get('Taken', _currentLanguage),
                false,
              ),
              _buildVerticalDivider(theme),
              _buildStatItem(
                theme,
                "${skippedCount + missedCount}",
                Translations.get('Missed', _currentLanguage),
                false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // History List
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: allEvents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "No records in the past 7 days",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allEvents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final event = allEvents[index];
                    final time = event['time'] as DateTime;
                    final status = event['status'] as String;
                    final color = event['color'] as Color;

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            status == 'Taken'
                                ? Icons.check
                                : status == 'Skipped'
                                ? Icons.skip_next
                                : Icons.priority_high,
                            color: color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Translations.get(status, _currentLanguage),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              Text(
                                DateFormat('EEEE, MMM d').format(time),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a').format(time),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String value,
    String label,
    bool isPrimary,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isPrimary
                ? theme.primaryColor
                : theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVerticalDivider(ThemeData theme) {
    return Container(height: 32, width: 1, color: theme.dividerColor);
  }
}
