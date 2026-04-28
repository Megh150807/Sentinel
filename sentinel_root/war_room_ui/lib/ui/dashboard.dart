import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import 'threat_feed.dart';
import 'ring_detection_panel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        title: const Text(
          'SENTINEL // CLOUD RUN',
          style: TextStyle(color: Colors.cyan, letterSpacing: 2.0, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
                    decoration: BoxDecoration(color: state.isSimulating ? Colors.redAccent : Colors.cyan, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isSimulating ? 'LIVE STREAMING' : 'IDLE',
                    style: TextStyle(color: state.isSimulating ? Colors.redAccent : Colors.cyan, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF0D1117),
            child: Row(
              children: [
                Expanded(child: _buildStatBox('BLOCKED TX', state.blockedTransactions.toString(), Colors.redAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatBox('TOTAL PROCESSED', state.alerts.length.toString(), Colors.cyan)),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.withOpacity(0.2),
                      foregroundColor: Colors.cyan,
                      side: const BorderSide(color: Colors.cyan),
                      minimumSize: const Size(double.infinity, 80),
                    ),
                    onPressed: state.isSimulating ? null : () {
                       ref.read(appStateProvider.notifier).startSimulation();
                    },
                    child: const Text("START SIMULATION", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                  )
                ),
              ],
            ),
          ),
          
          // Ring Detection Panel (appears when a mule chain is detected)
          const RingDetectionPanel(),
          
          // Expanded Threat Feed taking up the rest of the screen
          const Expanded(child: ThreatFeedVisualizer()),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }
}
