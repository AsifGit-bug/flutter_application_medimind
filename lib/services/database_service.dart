import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../models/notification_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user role and data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      // debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Update User Role (for Admin fixes)
  Future<void> updateUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).set({
      'role': role,
    }, SetOptions(merge: true));
  }

  Future<void> updateUserName(String uid, String newName) async {
    await _firestore.collection('users').doc(uid).update({
      'name': newName.trim(),
    });
  }

  // Ensure Admin User Exists (Self-healing)
  Future<void> ensureAdminUser(String uid, String email) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': 'admin',
      'active': true,
      'isVerified': true,
      'isDeleted': false,
      // Default name to "Admin" if missing (merge usage)
      // We can't easily conditionally set name only if missing in one go without reading.
      // But since this is specific for the hardcoded admins, it's safer to ensure they exist.
    }, SetOptions(merge: true));

    // Check if name exists, if not set it
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || !doc.data()!.containsKey('name')) {
      await _firestore.collection('users').doc(uid).update({
        'name': 'Admin Staff',
      });
    }
  }

  // Toggle User Active Status
  Future<void> toggleUserActiveStatus(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({'active': isActive});
  }

  // Set User as Verified
  Future<void> verifyUser(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'isVerified': true,
    }, SetOptions(merge: true));
  }

  // Create User Doc (for self-healing)
  Future<void> createUserDoc(
    String uid,
    String email,
    String role,
    String name,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
      'isDeleted': false,
      'isVerified': false, // Default to false until first login
      if (role == 'monitor' || role == 'guardian') 'linkedPatients': [],
      if (role == 'patient') 'caregivers': [],
    });
  }

  // Admin: Get All Users
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        // Ensure defaults
        data['id'] = doc.id;
        data['name'] = data['name'] ?? 'Unknown';
        data['email'] = data['email'] ?? 'No Email';
        data['role'] = data['role'] ?? 'patient';
        data['active'] = data['active'] ?? true;
        data['isDeleted'] = data['isDeleted'] ?? false;
        data['isVerified'] = data['isVerified'] ?? false;
        return data;
      }).toList();
    });
  }

  // Delete User (Soft Delete)
  Future<void> deleteUser(String uid) async {
    // We soft delete so we can maintain the ban status and totals
    await _firestore.collection('users').doc(uid).update({
      'active': false,
      'isDeleted': true,
    });
  }

  // --- Medicine Operations ---

  // Check if Medicine Exists (Duplicate Prevention)
  Future<bool> checkMedicineExists(
    String userId,
    String name,
    String type,
    String dosage,
  ) async {
    final query = await _firestore
        .collection('medicines')
        .where('userId', isEqualTo: userId)
        .where('name', isEqualTo: name.trim())
        .where('type', isEqualTo: type)
        .where('dosage', isEqualTo: dosage.trim())
        .get();

    return query.docs.isNotEmpty;
  }

  // Add Medicine
  Future<void> addMedicine(Medicine medicine, String userId) async {
    await _firestore.collection('medicines').add({
      'userId': userId,
      'name': medicine.name,
      'dosage': medicine.dosage,
      'type': medicine.type,
      'frequency': medicine.frequency,
      'time': Timestamp.fromDate(medicine.time),
      'scheduleTimes': medicine.scheduleTimes
          .map((e) => Timestamp.fromDate(e))
          .toList(),
      'instructions': medicine.instructions,
      'mealInstruction': medicine.mealInstruction,
      'weeklyDays': medicine.weeklyDays,
      'doseHistory': medicine.doseHistory
          .map((e) => Timestamp.fromDate(e))
          .toList(),
      'skipHistory': [],
      'missedHistory': [],
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  // Update Medicine
  Future<void> updateMedicine(Medicine medicine, String userId) async {
    await _firestore.collection('medicines').doc(medicine.id).update({
      'name': medicine.name,
      'dosage': medicine.dosage,
      'type': medicine.type,
      'frequency': medicine.frequency,
      'time': Timestamp.fromDate(medicine.time),
      'scheduleTimes': medicine.scheduleTimes
          .map((e) => Timestamp.fromDate(e))
          .toList(),
      'instructions': medicine.instructions,
      'mealInstruction': medicine.mealInstruction,
      'weeklyDays': medicine.weeklyDays,
      'isDeleted': medicine.isDeleted,
      'doseHistory': medicine.doseHistory
          .map((e) => Timestamp.fromDate(e))
          .toList(),
    });
  }

  // Get Medicines Stream
  Stream<List<Medicine>> getMedicines(String userId) {
    return _firestore
        .collection('medicines')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            DateTime primaryTime = (data['time'] as Timestamp).toDate();

            // Handle scheduleTimes (backward compatibility)
            List<DateTime> scheduleTimes = [];
            if (data['scheduleTimes'] != null) {
              scheduleTimes = (data['scheduleTimes'] as List<dynamic>)
                  .map((e) => (e as Timestamp).toDate())
                  .toList();
            } else {
              scheduleTimes = [primaryTime];
            }

            return Medicine(
              id: doc.id,
              name: data['name'] ?? '',
              dosage: data['dosage'] ?? '',
              frequency: data['frequency'] ?? '',
              time: primaryTime,
              scheduleTimes: scheduleTimes,
              type: data['type'] ?? 'Pill',
              instructions: data['instructions'] ?? '',
              mealInstruction: data['mealInstruction'] ?? 'None',
              weeklyDays:
                  (data['weeklyDays'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              doseHistory:
                  (data['doseHistory'] as List<dynamic>?)
                      ?.map((e) => (e as Timestamp).toDate())
                      .toList() ??
                  [],
              skipHistory:
                  (data['skipHistory'] as List<dynamic>?)
                      ?.map((e) => (e as Timestamp).toDate())
                      .toList() ??
                  [],
              missedHistory:
                  (data['missedHistory'] as List<dynamic>?)
                      ?.map((e) => (e as Timestamp).toDate())
                      .toList() ??
                  [],
              createdAt: data['createdAt'] != null
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null,
              isDeleted: data['isDeleted'] ?? false,
            );
          }).toList();
        });
  }

  // Get Linked Caregivers (For Patients)
  Stream<List<Map<String, dynamic>>> getLinkedCaregivers(String patientId) {
    return _firestore.collection('users').doc(patientId).snapshots().asyncMap((
      patientDoc,
    ) async {
      if (!patientDoc.exists) return [];
      final data = patientDoc.data() as Map<String, dynamic>;
      final caregivers = List<String>.from(data['caregivers'] ?? []);

      if (caregivers.isEmpty) return [];

      List<Map<String, dynamic>> caregiverDetails = [];
      for (String uid in caregivers) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userData['uid'] = uid; // Ensure UID is available
          caregiverDetails.add(userData);
        }
      }
      return caregiverDetails;
    });
  }

  // Delete Medicine (Soft Delete/Archive)
  Future<void> deleteMedicine(String medicineId) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'isDeleted': true,
    });
  }

  // Permanent Delete
  Future<void> hardDeleteMedicine(String medicineId) async {
    await _firestore.collection('medicines').doc(medicineId).delete();
  }

  // Log Dose (Take Medicine)
  Future<void> logDose(String medicineId, DateTime time) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'doseHistory': FieldValue.arrayUnion([Timestamp.fromDate(time)]),
    });
  }

  // Skip Dose
  Future<void> skipDose(String medicineId, DateTime time) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'skipHistory': FieldValue.arrayUnion([Timestamp.fromDate(time)]),
    });
  }

  // Mark as Missed (Explicitly)
  Future<void> markAsMissed(String medicineId, DateTime time) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'missedHistory': FieldValue.arrayUnion([Timestamp.fromDate(time)]),
    });
  }

  // --- Monitor Operations ---

  // Link Patient by Email
  // --- Monitor Request Flow ---

  // 1. Send Monitor Request
  Future<String> sendMonitorRequest(
    String monitorId,
    String patientEmail,
  ) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('email', isEqualTo: patientEmail)
          .where('role', isEqualTo: 'patient')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return "Patient not found with that email.";
      }

      DocumentSnapshot patientDoc = query.docs.first;
      String patientId = patientDoc.id;

      if (monitorId == patientId) {
        return "You cannot monitor yourself.";
      }

      // Check if already linked
      DocumentSnapshot monitorDoc = await _firestore
          .collection('users')
          .doc(monitorId)
          .get();

      if (!monitorDoc.exists || monitorDoc.data() == null) {
        // If monitor doc doesn't exist, we can assume no linked patients yet,
        // or we might need to create it. For now, just proceed as if not linked.
        // But waiting... if it doesn't exist, maybe we should error or handle gracefully?
        // In ensureAdminUser etc we create it.
        // Let's safe cast.
      }

      Map<String, dynamic>? monitorData =
          monitorDoc.data() as Map<String, dynamic>?;
      List<dynamic> linked = monitorData?['linkedPatients'] ?? [];

      if (linked.length >= 5) {
        return "You have reached the maximum limit of 5 patients.";
      }

      if (linked.contains(patientId)) {
        return "Patient is already linked.";
      }

      // Check if request already exists
      QuerySnapshot existingRequests = await _firestore
          .collection('requests')
          .where('monitorId', isEqualTo: monitorId)
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        return "Request already pending.";
      }

      // Create Request
      await _firestore.collection('requests').add({
        'monitorId': monitorId,
        'patientId': patientId,
        'patientEmail': patientEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Fetch Monitor Name for notification
      String monitorName = "A caregiver";
      if (monitorDoc.exists) {
        monitorData = monitorDoc.data() as Map<String, dynamic>?;
        monitorName = monitorData?['name'] ?? "A caregiver";
      }

      // Notify Patient
      await createNotification(
        userId: patientId,
        title: "New Monitor Request",
        body: "$monitorName wants to link with you as a caregiver.",
        type: NotificationType.request,
        targetId: monitorId,
        deepLink: 'monitor_requests',
      );

      return "Request sent successfully";
    } catch (e) {
      return "Error sending request: $e";
    }
  }

  // 2. Get Pending Requests (for Patient)
  Stream<List<Map<String, dynamic>>> getPendingRequests(String patientId) {
    return _firestore
        .collection('requests')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> requests = [];
          for (var doc in snapshot.docs) {
            var data = doc.data();
            data['id'] = doc.id;
            // Fetch monitor details to show who is asking
            DocumentSnapshot monitorDoc = await _firestore
                .collection('users')
                .doc(data['monitorId'])
                .get();
            if (monitorDoc.exists) {
              var mData = monitorDoc.data() as Map<String, dynamic>;
              data['monitorEmail'] = mData['email'] ?? 'Unknown';
            }
            requests.add(data);
          }
          return requests;
        });
  }

  // 3. Accept Request
  Future<String> acceptRequest(
    String requestId,
    String monitorId,
    String patientId,
  ) async {
    try {
      // Check limits before accepting
      DocumentSnapshot patientDoc = await _firestore
          .collection('users')
          .doc(patientId)
          .get();
      Map<String, dynamic>? patientData =
          patientDoc.data() as Map<String, dynamic>?;
      List<dynamic> currentCaregivers = patientData?['caregivers'] ?? [];

      if (currentCaregivers.length >= 5) {
        return "You already have the maximum number of caregivers (5).";
      }

      DocumentSnapshot monitorDoc = await _firestore
          .collection('users')
          .doc(monitorId)
          .get();
      Map<String, dynamic>? monitorData =
          monitorDoc.data() as Map<String, dynamic>?;
      List<dynamic> currentPatients = monitorData?['linkedPatients'] ?? [];

      if (currentPatients.length >= 5) {
        return "This monitor has reached their patient limit.";
      }

      // Perform the link
      await _firestore.collection('users').doc(monitorId).update({
        'linkedPatients': FieldValue.arrayUnion([patientId]),
      });
      await _firestore.collection('users').doc(patientId).update({
        'caregivers': FieldValue.arrayUnion([monitorId]),
      });
      // Update request status
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'accepted',
      });

      // Notify Monitor
      await createNotification(
        userId: monitorId,
        title: "Request Accepted",
        body:
            "${patientData?['name'] ?? 'Patient'} has accepted your link request.",
        type: NotificationType.success,
        targetId: patientId,
      );

      return "Request accepted successfully";
    } catch (e) {
      return "Error: $e";
    }
  }

  // 5. Unlink Patient
  Future<void> unlinkPatient(String monitorId, String patientId) async {
    await _firestore.collection('users').doc(monitorId).update({
      'linkedPatients': FieldValue.arrayRemove([patientId]),
      'patientNicknames.$patientId': FieldValue.delete(),
    });
    await _firestore.collection('users').doc(patientId).update({
      'caregivers': FieldValue.arrayRemove([monitorId]),
    });
  }

  // 6. Update Patient Nickname
  Future<void> updatePatientNickname(
    String monitorId,
    String patientId,
    String nickname,
  ) async {
    if (nickname.trim().isEmpty) {
      // If empty, remove the nickname entry to restore default name
      await _firestore.collection('users').doc(monitorId).update({
        'patientNicknames.$patientId': FieldValue.delete(),
      });
    } else {
      await _firestore.collection('users').doc(monitorId).set({
        'patientNicknames': {patientId: nickname.trim()},
      }, SetOptions(merge: true));
    }
  }

  // 7. Remove Patient (Duplicate logic for naming consistency)
  Future<void> removePatientFromMonitor(
    String monitorId,
    String patientId,
  ) async {
    await _firestore.collection('users').doc(monitorId).update({
      'linkedPatients': FieldValue.arrayRemove([patientId]),
      'patientNicknames.$patientId': FieldValue.delete(),
    });
    await _firestore.collection('users').doc(patientId).update({
      'caregivers': FieldValue.arrayRemove([monitorId]),
    });
  }

  // Get Linked Patients Stream
  Stream<List<Map<String, dynamic>>> getLinkedPatients(String monitorId) {
    return _firestore.collection('users').doc(monitorId).snapshots().asyncMap((
      monitorSnapshot,
    ) async {
      if (!monitorSnapshot.exists) return [];

      Map<String, dynamic> data =
          monitorSnapshot.data() as Map<String, dynamic>;
      List<dynamic> linkedIds = data['linkedPatients'] ?? [];
      Map<String, dynamic> nicknames = data['patientNicknames'] ?? {};

      if (linkedIds.isEmpty) return [];

      // Fetch details for each patient
      List<Map<String, dynamic>> patients = [];
      final List<dynamic> mutedPatients = data['mutedPatients'] ?? [];

      for (String pid in linkedIds) {
        DocumentSnapshot pDoc = await _firestore
            .collection('users')
            .doc(pid)
            .get();
        if (pDoc.exists) {
          Map<String, dynamic> pData = pDoc.data() as Map<String, dynamic>;
          pData['id'] = pid; // Ensure ID is attached
          pData['nickname'] = nicknames[pid]; // Attach nickname if exists
          pData['isMuted'] = mutedPatients.contains(pid); // Attach mute status

          // Calculate stats (Mock logic or real aggregation)
          QuerySnapshot meds = await _firestore
              .collection('medicines')
              .where('userId', isEqualTo: pid)
              .get();
          pData['medicineCount'] = meds.docs.length;
          patients.add(pData);
        }
      }
      return patients;
    });
  }

  // 4. Decline Request
  Future<void> declineRequest(String requestId) async {
    final doc = await _firestore.collection('requests').doc(requestId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final monitorId = data['monitorId'];
    // final patientId = data['patientId']; // Unused
    // final status = data['status']; // 'pending'

    await _firestore.collection('requests').doc(requestId).update({
      'status': 'declined',
    });

    // Notify Monitor that Patient declined (or vice versa - usually patient declines a request)
    // Assuming the current user performing this action is the one DECLINING.
    // If I am the patient, I decline the monitor's request.
    // If I am the monitor, I might cancel/decline? Usually 'decline' is recipient action.
    // Let's notify the sender (Monitor).
    // Fetch patient name for notification
    String patientName = "Patient";
    final patientId = data['patientId'];
    if (patientId != null) {
      final pDoc = await _firestore.collection('users').doc(patientId).get();
      if (pDoc.exists) {
        patientName = pDoc.data()?['name'] ?? "Patient";
      }
    }

    await createNotification(
      userId: monitorId,
      title: "Request Declined",
      body: "$patientName has declined your connection request.",
      type: NotificationType.warning,
      targetId: requestId,
    );
  }

  // --- Mute/Unmute Patients (Monitor Side) ---

  Future<void> mutePatient(String monitorId, String patientId) async {
    await _firestore.collection('users').doc(monitorId).update({
      'mutedPatients': FieldValue.arrayUnion([patientId]),
    });
  }

  Future<void> unmutePatient(String monitorId, String patientId) async {
    await _firestore.collection('users').doc(monitorId).update({
      'mutedPatients': FieldValue.arrayRemove([patientId]),
    });
  }

  // Helper to check mute status (mostly for UI, usually done via snapshot)
  Future<bool> isPatientMuted(String monitorId, String patientId) async {
    final doc = await _firestore.collection('users').doc(monitorId).get();
    if (!doc.exists) return false;
    final List<dynamic> muted = doc.data()?['mutedPatients'] ?? [];
    return muted.contains(patientId);
  }

  // --- Bug Reporting System ---

  // 1. Report Bug (Create)
  Future<void> reportBug(
    String userId,
    String email,
    String title,
    String description,
  ) async {
    await _firestore.collection('bugs').add({
      'userId': userId,
      'userEmail': email,
      'title': title,
      'description': description,
      'status': 'Open', // Open, Resolved
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Get All Bugs (Read - Admin)
  Stream<List<Map<String, dynamic>>> getAllBugs() {
    return _firestore
        .collection('bugs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            var data = doc.data();
            data['id'] = doc.id;
            // Handle timestamp safely
            if (data['createdAt'] is Timestamp) {
              data['date'] = (data['createdAt'] as Timestamp)
                  .toDate()
                  .toString();
            } else {
              data['date'] = 'Just now';
            }
            return data;
          }).toList();
        });
  }

  // 3. Resolve Bug (Update)
  Future<void> resolveBug(String bugId) async {
    await _firestore.collection('bugs').doc(bugId).update({
      'status': 'Resolved',
    });
  }

  // 4. Delete Bug (Delete)
  Future<void> deleteBug(String bugId) async {
    await _firestore.collection('bugs').doc(bugId).delete();
  }

  // --- App Content Management (About Us, FAQ, Privacy) ---

  // Get App Content Stream
  Stream<Map<String, dynamic>> getAppContent() {
    return _firestore
        .collection('app_metadata')
        .doc('content')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  // Update App Content
  Future<void> updateAppContent(Map<String, String> content) async {
    await _firestore
        .collection('app_metadata')
        .doc('content')
        .set(content, SetOptions(merge: true));
  }
  // --- In-App Notifications ---

  // Create Notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    required String targetId,
    String? deepLink,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': type.toString().split('.').last,
          'targetId': targetId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'deepLink': deepLink,
        });
  }

  // Get Notifications Stream
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return NotificationModel.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // Mark As Read
  Future<void> markNotificationAsRead(
    String userId,
    String notificationId,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark All As Read
  Future<void> markAllNotificationsAsRead(String userId) async {
    final batch = _firestore.batch();
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
