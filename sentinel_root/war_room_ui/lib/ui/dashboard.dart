import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import 'node_graph.dart';
import 'threat_feed.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF050505), // Deep dark slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        title: const Text(
          'SENTINEL // COMMAND',
          style: TextStyle(
            color: Colors.cyan,
            letterSpacing: 2.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: const Color(0xFF0D1117),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatBox('BLOCKED TX', state.blockedTransactions.toString(), Colors.redAccent),
                      const SizedBox(height: 16),
                      _buildStatBox('NETWORK LATENCY', '< 12 ms', Colors.cyan),
                       const SizedBox(height: 16),
                      _buildStatBox('THREAT STATUS', state.blockedTransactions > 0 ? 'CRITICAL' : 'NOMINAL', state.blockedTransactions > 0 ? Colors.redAccent : Colors.cyan),
                      const Spacer(),
                      
                      // Mock Intercept Button for local demo without Firebase
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.2),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                           ref.read(appStateProvider.notifier).injectMockAlert();
                        },
                        child: const Text("SIMULATE INTERCEPT", style: TextStyle(letterSpacing: 1.2)),
                      )
                    ],
                  ),
                ),
                // Main Graph
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: NodeGraphVisualizer(),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Threat Feed
          const ThreatFeedVisualizer(),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
