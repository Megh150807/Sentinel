import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiThreatReporter {
  // Point this to your new Cloud Run Python Proxy URL once deployed.
  // Example: 'https://sentinel-gemini-proxy-xxxxx-el.a.run.app/generate_report'
  final String proxyUrl;

  GeminiThreatReporter({this.proxyUrl = "https://sentinel-gemini-proxy-647109791978.asia-south1.run.app/generate_report"});

  Future<String> getThreatReport(Map<String, dynamic> alert) async {
    try {
      final response = await http.post(
        Uri.parse(proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "transaction_id": alert['transaction_id'] ?? "UNKNOWN",
          "ptr": alert['ptr'] ?? 0.0,
          "jitter_ms": alert['jitter_ms'] ?? 0.0,
          "status": alert['status'] ?? "UNKNOWN"
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['report'] ?? "No report generated.";
      } else {
        return "⚠️ PROXY ERROR [${response.statusCode}]: Failed to reach AI Intelligence backend.\n\nVerify that the Python Gemini Proxy is online and accessible.";
      }
    } catch (e) {
      return "⚠️ NETWORK ERROR: Failed to connect to Gemini Proxy.\n\nEnsure your proxy is running. Error: $e";
    }
  }
}
