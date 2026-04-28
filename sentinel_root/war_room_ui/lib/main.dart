import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ui/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD3bhFkPYflpz4E1tQ8ga48ObB-tmnVFU4",
        authDomain: "sentinel-v1-ea749.firebaseapp.com",
        projectId: "sentinel-v1-ea749",
        storageBucket: "sentinel-v1-ea749.firebasestorage.app",
        messagingSenderId: "647109791978",
        appId: "1:647109791978:web:7444afe0c9b2c1e5bf0793",
        measurementId: "G-NLVE5JC1YJ",
      ),
    );
  } catch (e) {
     debugPrint("Firebase init failed: $e. Running in mock mode.");
  }
  
  runApp(
    const ProviderScope(
      child: SentinelApp(),
    ),
  );
}

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel Command',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        fontFamily: 'Roboto', 
      ),
      home: const DashboardScreen(),
    );
  }
}
