import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DemoSimulatorService {
  final String targetUrl;
  
  // Default to 127.0.0.1 to avoid Chrome IPv6 resolution failing against WSL2's IPv4 bind
  DemoSimulatorService({this.targetUrl = "https://sentinel-v1-backend-647109791978.asia-south1.run.app/intercept"});

  Future<void> startSimulation(Function(Map<String, dynamic> result) onResult) async {
    try {
      // Load mock JSON
      final String response = await rootBundle.loadString('lib/assets/mock_telemetry.json');
      final List<dynamic> data = json.decode(response);

      debugPrint("Starting telemetry simulation targeting $targetUrl...");

      for (var transaction in data) {
        try {
          final res = await http.post(
            Uri.parse(targetUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(transaction),
          );

          if (res.statusCode == 200) {
            final result = json.decode(res.body);
            // Merge original transaction data with the engine's verdict
            final mergedResult = <String, dynamic>{
              ...Map<String, dynamic>.from(transaction as Map),
              ...Map<String, dynamic>.from(result),
            };
            onResult(mergedResult);
          } else {
            debugPrint("Engine error: ${res.statusCode}");
          }
        } catch (e) {
            debugPrint("Network error: $e");
            // If backend is down, just yield local mocked result for UI testing
            onResult(<String, dynamic>{
              ...Map<String, dynamic>.from(transaction as Map),
              'status': 'error',
              'latency_us': 0,
              'ml_risk_score': 0.0,
              'centrality_score': 0.0,
              'error': 'Backend Unreachable'
            });
        }
        
        // 500ms delay to make it look like a live feed
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      debugPrint("Simulation complete.");

    } catch (e) {
      debugPrint("Error loading mock telemetry: $e");
    }
  }
}
