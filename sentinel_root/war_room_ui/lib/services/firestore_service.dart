import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

final alertsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.listenToAlerts();
});

class FirestoreService {
  FirebaseFirestore? _db;

  FirestoreService() {
    try {
      _db = FirebaseFirestore.instance;
    } catch (e) {
      // Allow running the UI locally without Firebase fully configured
    }
  }

  Stream<List<Map<String, dynamic>>> listenToAlerts() {
    if (_db == null) return Stream.value([]); // Disabled stream fallback
    
    return _db!
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
