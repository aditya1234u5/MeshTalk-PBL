import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/peer.dart';
import '../services/ble_mesh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/mesh_topology_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showTopology = false;

  void _send(BleMeshService mesh) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    mesh.sendMessage(text);
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<BleMeshService>();
    final connectedCount =
        mesh.peers.where((p) => p.linkState == PeerLinkState.connected).length;
    final isLive = connectedCount > 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StatusStrip(
              displayName: mesh.selfDisplayName,
              connectedCount: connectedCount,
              isLive: isLive,
              showTopology: _showTopology,
              onToggleTopology: () => setState(() => _showTopology = !_showTopology),
            ),
            Expanded(
              child: _showTopology
                  ? MeshTopologyView(directNeighbors: mesh.directNeighbors)
                  : mesh.messages.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          itemCount: mesh.messages.length,
                          itemBuilder: (context, index) =>
                              MessageBubble(message: mesh.messages[index]),
                        ),
            ),
            if (!_showTopology) _Composer(controller: _textController, onSend: () => _send(mesh)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Replaces the generic AppBar with something that actually reports mesh
/// state: your own name (the "callsign"), a live/idle indicator, and a
/// tap-to-toggle topology view.
class _StatusStrip extends StatelessWidget {
  final String displayName;
  final int connectedCount;
  final bool isLive;
  final bool showTopology;
  final VoidCallback onToggleTopology;

  const _StatusStrip({
    required this.displayName,
    required this.connectedCount,
    required this.isLive,
    required this.showTopology,
    required this.onToggleTopology,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? AppColors.link : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isLive
                      ? '$connectedCount peer${connectedCount == 1 ? '' : 's'} in range'
                      : 'scanning for peers...',
                  style: AppText.mono.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: showTopology ? 'Back to chat' : 'Mesh topology',
            icon: Icon(
              showTopology ? Icons.forum_outlined : Icons.hub_outlined,
              color: AppColors.textMuted,
            ),
            onPressed: onToggleTopology,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_searching, color: AppColors.textMuted, size: 32),
            const SizedBox(height: 14),
            const Text(
              'No signal yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Messages appear here once another device\nrunning bitmesh comes within Bluetooth range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 16,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Transmit a message...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.signal),
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward, color: AppColors.background),
          ),
        ],
      ),
    );
  }
}
