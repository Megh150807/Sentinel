import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';

class ThreatFeedVisualizer extends ConsumerWidget {
  const ThreatFeedVisualizer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final alerts = state.alerts;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.cyan, width: 0.5)),
      ),
      child: alerts.isEmpty
          ? const Center(
              child: Text(
                "AWAITING TELEMETRY...",
                style: TextStyle(color: Colors.white30, fontFamily: 'monospace', letterSpacing: 2.0),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                return _buildAlertCard(alerts[index]);
              },
            ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isBlocked = alert['status'] == 'blocked';
    final isError = alert['status'] == 'error';
    final cardColor = isError ? Colors.amber : (isBlocked ? Colors.redAccent : Colors.cyan);
    final txnId = alert['transaction_id'] ?? 'UNKNOWN';
    final latency = alert['latency_us'] ?? 0;
    final mlRisk = (alert['ml_risk_score'] ?? 0.0).toDouble();
    final centrality = (alert['centrality_score'] ?? 0.0).toDouble();
    final ptr = alert['ptr'] ?? 0.0;
    final jitter = alert['jitter_ms'] ?? 0.0;
    
    final senderUpi = alert['sender_upi'] ?? '';
    final receiverUpi = alert['receiver_upi'] ?? '';
    
    final geminiReport = alert['gemini_report'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.05),
        border: Border.all(color: cardColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: TX ID + Latency ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TX // $txnId',
                style: TextStyle(color: cardColor, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              Text(
                '${latency}μs',
                style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),
          if (senderUpi.isNotEmpty && receiverUpi.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$senderUpi  →  $receiverUpi',
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),

          // ── Telemetry Row: PTR | Jitter | Status Badge ──
          Row(
            children: [
              Text(
                "PTR: ${(ptr is double ? ptr.toStringAsFixed(2) : ptr)}  |  Jitter: ${(jitter is double ? jitter.toStringAsFixed(0) : jitter)}ms",
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  isError ? 'ERROR' : (isBlocked ? 'BLOCKED' : 'ALLOWED'),
                  style: TextStyle(color: cardColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── ML Risk + Centrality Gauges ──
          Row(
            children: [
              // ML Risk Score Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ML RISK: ${mlRisk.toStringAsFixed(3)}',
                      style: TextStyle(
                        color: mlRisk > 0.7 ? Colors.redAccent : Colors.amber,
                        fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: mlRisk.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          mlRisk > 0.7 ? Colors.redAccent : (mlRisk > 0.4 ? Colors.amber : Colors.cyan),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Graph Centrality Score Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CENTRALITY: ${centrality.toStringAsFixed(3)}',
                      style: TextStyle(
                        color: centrality > 0.5 ? Colors.purpleAccent : Colors.white54,
                        fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: centrality.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          centrality > 0.5 ? Colors.purpleAccent : Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Gemini AI Report (only for blocked) ──
          if (isBlocked && geminiReport.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.psychology, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      geminiReport,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
