import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/stat_card.dart';

class PatientCard extends StatelessWidget {
  final String name;
  final String email;
  final String avatarLetter;
  final int taken;
  final int pending;
  final int missed;
  final int adherence;

  const PatientCard({
    super.key,
    required this.name,
    required this.email,
    required this.avatarLetter,
    required this.taken,
    required this.pending,
    required this.missed,
    required this.adherence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(
                    0xFFE0F2F1,
                  ), // Light teal background
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      color: Color(0xFF009688), // Teal text
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                StatCard(
                  label: 'Taken',
                  count: taken,
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF4CAF50), // Green
                  backgroundColor: const Color(0xFFE8F5E9),
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Pending',
                  count: pending,
                  icon: Icons.access_time,
                  color: const Color(0xFFFFA000), // Amber
                  backgroundColor: const Color(0xFFFFF8E1),
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Missed',
                  count: missed,
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFEF5350), // Red
                  backgroundColor: const Color(0xFFFFEBEE),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Adherence',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  '$adherence%',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
