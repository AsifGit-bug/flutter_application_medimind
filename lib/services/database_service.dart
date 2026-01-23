import 'package:cloud_firestore/cloud_firestore.dart';
import '../medicine_model.dart';

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

  // Toggle User Active Status
  Future<void> toggleUserActiveStatus(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({'active': isActive});
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
        data['active'] = true; // Default to true unless we add ban logic
        // Convert timestamp to string if needed, or keep as is
        return data;
      }).toList();
    });
  }

  // --- Medicine Operations ---

  // Add Medicine
  Future<void> addMedicine(Medicine medicine, String userId) async {
    await _firestore.collection('medicines').add({
      'userId': userId,
      'name': medicine.name,
      'dosage': medicine.dosage,
      'type': medicine.type,
      'frequency': medicine.frequency,
      'time': Timestamp.fromDate(medicine.time),
      'instructions': medicine.instructions,
      'doseHistory': medicine.doseHistory
          .map((e) => Timestamp.fromDate(e))
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
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
            return Medicine(
              id: doc.id,
              name: data['name'] ?? '',
              dosage: data['dosage'] ?? '',
              frequency: data['frequency'] ?? '',
              time: (data['time'] as Timestamp).toDate(),
              type: data['type'] ?? 'Pill',
              instructions: data['instructions'] ?? '',
              doseHistory:
                  (data['doseHistory'] as List<dynamic>?)
                      ?.map((e) => (e as Timestamp).toDate())
                      .toList() ??
                  [],
            );
          }).toList();
        });
  }

  // Delete Medicine
  Future<void> deleteMedicine(String medicineId) async {
    await _firestore.collection('medicines').doc(medicineId).delete();
  }

  // Log Dose (Take Medicine)
  Future<void> logDose(String medicineId, DateTime time) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'doseHistory': FieldValue.arrayUnion([Timestamp.fromDate(time)]),
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

      // Check if already linked
      DocumentSnapshot monitorDoc = await _firestore
          .collection('users')
          .doc(monitorId)
          .get();
      List<dynamic> linked =
          (monitorDoc.data() as Map<String, dynamic>)['linkedPatients'] ?? [];
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
  Future<void> acceptRequest(
    String requestId,
    String monitorId,
    String patientId,
  ) async {
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
  }

  // 4. Decline Request
  Future<void> declineRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  // 5. Unlink Patient
  Future<void> unlinkPatient(String monitorId, String patientId) async {
    await _firestore.collection('users').doc(monitorId).update({
      'linkedPatients': FieldValue.arrayRemove([patientId]),
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

      if (linkedIds.isEmpty) return [];

      // Fetch details for each patient
      // Note: In a real app, optimize this to avoid N+1 reads or use a collection group if possible
      List<Map<String, dynamic>> patients = [];
      for (String pid in linkedIds) {
        DocumentSnapshot pDoc = await _firestore
            .collection('users')
            .doc(pid)
            .get();
        if (pDoc.exists) {
          Map<String, dynamic> pData = pDoc.data() as Map<String, dynamic>;
          pData['id'] = pid; // Ensure ID is attached
          // Calculate stats (Mock logic or real aggregation)
          // For now, let's fetch their medicines count to show *something* real
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
}
