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
      height: 140, // Fixed bottom drawer height
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF1F1F1F), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: const Color(0xFF1F1F1F),
            width: double.infinity,
            child: const Text(
              '// LIVE THREAT FEED',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: alerts.isEmpty
                ? const Center(
                    child: Text(
                      'NO ACTIVE THREATS.',
                      style: TextStyle(color: Colors.white24, fontFamily: 'monospace', letterSpacing: 2.0),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      return _buildAlertCard(alerts[index]);
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isBot = alert['verdict'] == 'BOT';
    final accentColor = isBot ? Colors.cyan : Colors.redAccent;
    final txnId = alert['txn_id'] ?? 'UNKNOWN';
    final amount = alert['amount']?.toString() ?? '...';
    // Remove "0." from front of timestamp
    final timestamp = alert['timestamp']?.toString().split('.').first.split('T').last ?? '--:--:--';
    final confidence = alert['confidence'] != null ? '${(alert['confidence'] * 100).toInt()}%' : '...';

    return Container(
      width: 250,
      margin: const EdgeInsets.fromLTRB(16, 12, 0, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        border: Border.all(color: accentColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: -2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(txnId, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
              Text(timestamp, style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 11)),
            ],
          ),
          Text('₹$amount INR', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)
                ),
                child: Text(alert['verdict'] ?? 'UNKNOWN', style: TextStyle(color: accentColor, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text('CONF: $confidence', style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }
}
