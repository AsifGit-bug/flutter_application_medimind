import 'package:flutter/material.dart';

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // Using Teal for the logo elements to match the app theme
    const Color primaryColor = Color(0xFF26A69A); // Teal
    // The image has a Blue Clock and Orange/Brown Bottle.
    // Let's stick to the App's Teal theme but maybe make the bottle pop or stick to Teal/Mint for "clean" look.
    // Let's match the image's shape but use our Teal theme.

    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // BIG MEDICINE BOTTLE (Background)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 8),
              color: primaryColor.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Icon(
                Icons.medication_rounded,
                size: 80,
                color: primaryColor,
              ),
            ),
          ),

          // CLOCK BADGE (Bottom Right Overlay)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: primaryColor,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
