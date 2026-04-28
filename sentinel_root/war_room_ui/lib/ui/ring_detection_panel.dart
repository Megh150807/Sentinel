import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';

class RingDetectionPanel extends ConsumerWidget {
  const RingDetectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final rings = state.detectedRings;

    if (rings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: rings.asMap().entries.map((entry) {
        final index = entry.key;
        final ring = entry.value;
        return _buildRingCard(ring, index + 1);
      }).toList(),
    );
  }

  Widget _buildRingCard(Map<String, dynamic> ring, int ringNumber) {
    final chain = List<String>.from(ring['chain'] ?? []);
    final evidenceTxns = List<String>.from(ring['evidence_txn_ids'] ?? []);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MULE RING #$ringNumber DETECTED',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${chain.length} nodes in chain  •  ${evidenceTxns.length} evidence transactions',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Chain Visualization ──
          const Text(
            'CHAIN',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildChainNodes(chain),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // ── Evidence Transactions ──
          Text(
            'EVIDENCE TRANSACTIONS (${evidenceTxns.length})',
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: evidenceTxns.map((txnId) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  txnId,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChainNodes(List<String> chain) {
    final List<Widget> widgets = [];

    for (int i = 0; i < chain.length; i++) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            border: Border.all(color: Colors.redAccent, width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              const Icon(Icons.account_circle, color: Colors.redAccent, size: 18),
              const SizedBox(height: 4),
              Text(
                chain[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

      if (i < chain.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, color: Colors.redAccent, size: 18),
          ),
        );
      }
    }

    return widgets;
  }
}
