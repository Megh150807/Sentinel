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
          painter: GraphPainter(alertCount: state.alerts.length),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final int alertCount;
  
  GraphPainter({required this.alertCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final paintEdge = Paint()
      ..color = Colors.cyan.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
      
    final paintNodeNormal = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;
      
    final paintNodeFlagged = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6.0); // Neon glow

    final random = Random(42); // Deterministic seed for static visual
    final nodes = <Offset>[];
    for(int i = 0; i < 60; i++) {
        nodes.add(Offset(
          random.nextDouble() * size.width, 
          random.nextDouble() * size.height
        ));
    }
    
    // Draw edges for nodes within 120px radius
    for(int i = 0; i < nodes.length; i++) {
      for(int j = i + 1; j < nodes.length; j++) {
         if ((nodes[i] - nodes[j]).distance < 120) {
            canvas.drawLine(nodes[i], nodes[j], paintEdge);
         }
      }
    }
    
    // Draw nodes
    for(int i = 0; i < nodes.length; i++) {
       // Flag randomized subset if we have alerts
       bool isFlagged = alertCount > 0 && (i % 11 == 0 || i % 13 == 0); 
       
       if (isFlagged) {
         canvas.drawCircle(nodes[i], 12.0, Paint()..color = Colors.redAccent.withOpacity(0.3));
       }
       canvas.drawCircle(nodes[i], isFlagged ? 6.0 : 3.0, isFlagged ? paintNodeFlagged : paintNodeNormal);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.alertCount != alertCount;
  }
}
