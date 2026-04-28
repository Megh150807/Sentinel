import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import 'dart:math';

class NodeGraphVisualizer extends ConsumerWidget {
  const NodeGraphVisualizer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: GraphPainter(alerts: state.alerts),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> alerts;
  
  GraphPainter({required this.alerts});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final paintEdge = Paint()
      ..color = Colors.cyan.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
      
    final paintNodeNormal = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;
      
    final paintNodeFlagged = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6.0);

    // Extract real nodes and edges from alerts
    Set<String> uniqueNodes = {};
    List<Map<String, String>> edges = [];
    Set<String> flaggedNodes = {};

    for (var alert in alerts) {
      if (alert.containsKey('node_id')) {
        flaggedNodes.add(alert['node_id'].toString());
      }
      if (alert.containsKey('edges') && alert['edges'] is List) {
        for (var edge in alert['edges']) {
            if (edge is Map) {
                // Handle different potential structures of edge (mock vs real firestore)
                String source = '';
                String target = '';
                
                // Real firestore structure
                if (edge.containsKey('mapValue') && edge['mapValue'].containsKey('fields')) {
                    final fields = edge['mapValue']['fields'];
                    if (fields.containsKey('source') && fields['source'].containsKey('stringValue')) {
                        source = fields['source']['stringValue'];
                    }
                    if (fields.containsKey('target') && fields['target'].containsKey('stringValue')) {
                        target = fields['target']['stringValue'];
                    }
                } else if (edge.containsKey('source') && edge.containsKey('target')) {
                    source = edge['source'].toString();
                    target = edge['target'].toString();
                }

                if (source.isNotEmpty && target.isNotEmpty) {
                    uniqueNodes.add(source);
                    uniqueNodes.add(target);
                    edges.add({'source': source, 'target': target});
                }
            }
        }
      }
    }

    // If no real data, fallback to a small generic cluster to show "monitoring" status
    if (uniqueNodes.isEmpty) {
       _drawMonitoringPulse(canvas, size);
       return;
    }

    // Assign consistent random positions to unique nodes based on their string hash
    Map<String, Offset> nodePositions = {};
    for (var node in uniqueNodes) {
       final random = Random(node.hashCode);
       nodePositions[node] = Offset(
           (random.nextDouble() * 0.8 + 0.1) * size.width, 
           (random.nextDouble() * 0.8 + 0.1) * size.height
       );
    }
    
    // Draw edges
    for (var edge in edges) {
      final p1 = nodePositions[edge['source']];
      final p2 = nodePositions[edge['target']];
      if (p1 != null && p2 != null) {
         canvas.drawLine(p1, p2, paintEdge);
      }
    }
    
    // Draw nodes
    for (var node in uniqueNodes) {
       final pos = nodePositions[node]!;
       bool isFlagged = flaggedNodes.contains(node);
       
       if (isFlagged) {
         canvas.drawCircle(pos, 16.0, Paint()..color = Colors.redAccent.withOpacity(0.2));
         canvas.drawCircle(pos, 8.0, paintNodeFlagged);
       } else {
         canvas.drawCircle(pos, 5.0, paintNodeNormal);
       }

       // Draw node label
       TextSpan span = TextSpan(style: TextStyle(color: isFlagged ? Colors.redAccent : Colors.cyan, fontSize: 10, fontFamily: 'monospace'), text: node);
       TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
       tp.layout();
       tp.paint(canvas, Offset(pos.dx + 10, pos.dy - 5));
    }
  }

  void _drawMonitoringPulse(Canvas canvas, Size size) {
     final center = Offset(size.width / 2, size.height / 2);
     canvas.drawCircle(center, 4.0, Paint()..color = Colors.cyan);
     
     // Draw a pulsing ring
     final pulsePhase = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0;
     canvas.drawCircle(center, 10.0 + (pulsePhase * 40.0), Paint()
        ..color = Colors.cyan.withOpacity(1.0 - pulsePhase)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
     );
     
     TextSpan span = const TextSpan(style: TextStyle(color: Colors.cyan, fontSize: 12, fontFamily: 'monospace', letterSpacing: 2.0), text: "AWAITING TELEMETRY...");
     TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
     tp.layout();
     tp.paint(canvas, Offset(center.dx - (tp.width/2), center.dy + 30));
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return true; // Simple way to allow the pulse animation or updates
  }
}
