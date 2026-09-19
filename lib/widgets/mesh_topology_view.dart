import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/peer.dart';
import '../theme/app_theme.dart';

/// Draws you at the center and each direct (1-hop) neighbor arranged
/// radially around you, connected by a line. This only ever shows direct
/// neighbors - see the README's "Known limitations" on why the full
/// multi-hop mesh can't be honestly drawn with flood-relay routing.
class MeshTopologyView extends StatelessWidget {
  final List<Peer> directNeighbors;

  const MeshTopologyView({super.key, required this.directNeighbors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) => CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _TopologyPainter(neighborCount: directNeighbors.length),
                child: _NodeLabels(neighbors: directNeighbors),
              ),
            ),
          ),
        ),
        if (directNeighbors.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Text(
              'No direct links yet - this view only shows\npeers you are connected to over BLE right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
          ),
      ],
    );
  }
}

class _NodeLabels extends StatelessWidget {
  final List<Peer> neighbors;
  const _NodeLabels({required this.neighbors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final radius = math.min(constraints.maxWidth, constraints.maxHeight) / 2 - 48;

        return Stack(
          children: [
            // Self node label
            Positioned(
              left: center.dx - 28,
              top: center.dy + 14,
              child: const _NodeChip(label: 'you', color: AppColors.signal),
            ),
            for (var i = 0; i < neighbors.length; i++)
              () {
                final angle = (2 * math.pi * i / neighbors.length) - (math.pi / 2);
                final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
                return Positioned(
                  left: pos.dx - 36,
                  top: pos.dy + 14,
                  child: _NodeChip(label: neighbors[i].displayName, color: AppColors.link),
                );
              }(),
          ],
        );
      },
    );
  }
}

class _NodeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _NodeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11),
      ),
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final int neighborCount;
  _TopologyPainter({required this.neighborCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 48;

    // Faint range ring, purely contextual.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (var i = 0; i < neighborCount; i++) {
      final angle = (2 * math.pi * i / neighborCount) - (math.pi / 2);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;

      canvas.drawLine(
        center,
        pos,
        Paint()
          ..color = AppColors.link.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(pos, 6, Paint()..color = AppColors.link);
    }

    // Self node.
    canvas.drawCircle(center, 9, Paint()..color = AppColors.signal);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = AppColors.signal.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) =>
      oldDelegate.neighborCount != neighborCount;
}