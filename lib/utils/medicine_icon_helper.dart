import 'package:flutter/material.dart';

/// Returns a Widget representing the medicine icon based on its type.
/// Uses custom assets for known types, fallback to Material Icon for unknown types.
Widget getMedicineIconWidget(String type, {double size = 24.0, Color? color}) {
  final lowerType = type.toLowerCase();

  // Map medicine types to their asset paths
  String? assetPath;
  switch (lowerType) {
    case 'pill':
    case 'capsule':
    case 'tablet':
      assetPath = 'assets/icons/pill.png';
      break;
    case 'syrup':
    case 'liquid':
      assetPath = 'assets/icons/syrup.png';
      break;
    case 'injection':
    case 'syringe':
      assetPath = 'assets/icons/injection.png';
      break;
    case 'inhaler':
      assetPath = 'assets/icons/inhaler.jpg';
      break;
    case 'drops':
      assetPath = 'assets/icons/drops.jpg';
      break;
    case 'other':
      assetPath = 'assets/icons/other.png';
      break;
    default:
      // Return a Material Icon for unknown types
      return Icon(Icons.medication_rounded, size: size, color: color);
  }

  // Wrap in ClipOval for proper circular display without a forced white background
  return ClipOval(
    child: Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to Material Icon if asset fails to load
        return Icon(Icons.medication_rounded, size: size, color: color);
      },
    ),
  );
}

/// Returns a smaller icon widget suitable for list items
Widget getMedicineIconSmall(String type, {Color? color}) {
  return getMedicineIconWidget(type, size: 20.0, color: color);
}

/// Returns a medium icon widget suitable for cards
Widget getMedicineIconMedium(String type, {Color? color}) {
  return getMedicineIconWidget(type, size: 32.0, color: color);
}

/// Returns a large icon widget suitable for detail pages
Widget getMedicineIconLarge(String type, {Color? color}) {
  return getMedicineIconWidget(type, size: 48.0, color: color);
}
