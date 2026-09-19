import 'dart:math';
import 'package:flutter/material.dart';
import '../models/peer.dart';

/// Draws the self device at the center with a line out to each directly
/// connected (1-hop) neighbor. This is deliberately NOT a full mesh graph -
/// flood relay carries no path information, so we only draw what we
/// actually know: our own direct connections. Labeling it "live mesh
/// topology" while only showing 1-hop neighbors would be misleading, so
/// the widget's title is explicit about that scope.
class MeshTopologyView extends StatelessWidget {
  final List<Peer> directNeighbors;

  const MeshTopologyView({super.key, required this.directNeighbors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Direct connections (1 hop)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        AspectRatio(
          aspectRatio: 1.3,
          child: CustomPaint(
            painter: _TopologyPainter(neighborCount: directNeighbors.length),
            child: _NeighborLabels(neighbors: directNeighbors),
          ),
        ),
      ],
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final int neighborCount;
  _TopologyPainter({required this.neighborCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 40;
    final linePaint = Paint()
      ..color = Colors.blue.shade200
      ..strokeWidth = 2;

    if (neighborCount == 0) return;

    for (var i = 0; i < neighborCount; i++) {
      final angle = (2 * pi * i / neighborCount) - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, point, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) =>
      oldDelegate.neighborCount != neighborCount;
}

class _NeighborLabels extends StatelessWidget {
  final List<Peer> neighbors;
  const _NeighborLabels({required this.neighbors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = Offset(size.width / 2, size.height / 2);
        final radius = min(size.width, size.height) / 2 - 40;

        return Stack(
          children: [
            // Self node, always centered.
            Positioned(
              left: center.dx - 24,
              top: center.dy - 24,
              child: const _NodeBubble(label: 'You', highlight: true),
            ),
            // One bubble per direct neighbor, evenly spaced in a circle.
            for (var i = 0; i < neighbors.length; i++)
              Builder(builder: (context) {
                final angle = (2 * pi * i / neighbors.length) - pi / 2;
                final point = Offset(
                  center.dx + radius * cos(angle),
                  center.dy + radius * sin(angle),
                );
                return Positioned(
                  left: point.dx - 24,
                  top: point.dy - 24,
                  child: _NodeBubble(
                    label: neighbors[i].displayName.isNotEmpty
                        ? neighbors[i].displayName
                        : neighbors[i].peerId.substring(0, 6),
                  ),
                );
              }),
            if (neighbors.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: center.dy + 40,
                child: const Center(
                  child: Text(
                    'No direct peers yet',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NodeBubble extends StatelessWidget {
  final String label;
  final bool highlight;
  const _NodeBubble({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlight ? Colors.blue.shade600 : Colors.green.shade600,
          ),
          child: Icon(
            highlight ? Icons.person : Icons.bluetooth_connected,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
