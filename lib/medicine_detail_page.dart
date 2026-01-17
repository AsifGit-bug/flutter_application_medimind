import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'medicine_model.dart';
import 'add_medicine_page.dart';

class MedicineDetailPage extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback onDelete;
  final Function(Medicine) onUpdate;

  const MedicineDetailPage({
    super.key,
    required this.medicine,
    required this.onDelete,
    required this.onUpdate,
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicinePage(medicine: widget.medicine),
      ),
    );

    if (result != null && result is Medicine) {
      widget.onUpdate(result);
      setState(() {}); // Rebuild local view
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Medicine?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete(); // Trigger delete callback
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWithBlueTint,
      appBar: AppBar(
        title: Text(
          widget.medicine.name,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueGrey),
            onPressed: _navigateToEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Medicine Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: darkBlue.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.medication, size: 40, color: primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.medicine.dosage,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.medicine.frequency,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey[200]),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoTile(
                        "Time",
                        DateFormat('hh:mm a').format(widget.medicine.time),
                      ),
                      _buildInfoTile("Status", "Active"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // History Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dose History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.medicine.doseHistory.isEmpty)
                    const Text(
                      "No history recorded yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ...widget.medicine.doseHistory.reversed
                      .take(5)
                      .map(
                        (date) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(DateFormat('MMM d, hh:mm a').format(date)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.blueGrey[900],
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
