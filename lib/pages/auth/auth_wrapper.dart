import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../auth/welcome_page.dart';
import '../patient/patient_dashboard.dart';
import '../monitor/monitor_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'role_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFE0F7FA), // Match Mint background
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF26A69A)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<List<dynamic>>(
            future: Future.wait([
              DatabaseService().getUserData(snapshot.data!.uid),
              SharedPreferences.getInstance(),
            ]),
            builder: (context, dataSnapshot) {
              if (dataSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFE0F7FA), // Match Mint background
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF26A69A)),
                  ),
                );
              }

              if (dataSnapshot.hasData && dataSnapshot.data != null) {
                final userData = dataSnapshot.data![0] as Map<String, dynamic>?;
                final prefs = dataSnapshot.data![1] as SharedPreferences;

                if (userData != null) {
                  final role = userData['role'];

                  // Check for persisted role preference
                  final lastRole = prefs.getString('last_dashboard_role');

                  // Priority: saved preference > default role logic
                  if (lastRole == 'patient') return const PatientDashboard();
                  if (lastRole == 'monitor') return const MonitorDashboard();

                  if (role == 'patient') return const PatientDashboard();
                  if (role == 'monitor' || role == 'guardian') {
                    return const MonitorDashboard();
                  }
                  if (role == 'admin') return const AdminDashboard();
                  return RoleSelectionPage(uid: snapshot.data!.uid);
                }
              }

              return const WelcomePage();
            },
          );
        }

        return const WelcomePage();
      },
    );
  }
}
