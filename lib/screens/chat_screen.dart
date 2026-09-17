import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/peer.dart';
import '../services/ble_mesh_service.dart';
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
    final connectedCount = mesh.peers.where((p) => p.linkState == PeerLinkState.connected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('bitmesh'),
        actions: [
          IconButton(
            tooltip: 'Mesh topology',
            icon: Icon(_showTopology ? Icons.chat : Icons.hub_outlined),
            onPressed: () => setState(() => _showTopology = !_showTopology),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                avatar: Icon(
                  connectedCount > 0 ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                  size: 18,
                  color: connectedCount > 0 ? Colors.green : Colors.grey,
                ),
                label: Text('$connectedCount nearby'),
              ),
            ),
          ),
        ],
      ),
      body: _showTopology
          ? MeshTopologyView(directNeighbors: mesh.directNeighbors)
          : Column(
        children: [
          Expanded(
            child: mesh.messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nWaiting for nearby peers...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: mesh.messages.length,
                    itemBuilder: (context, index) => MessageBubble(message: mesh.messages[index]),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Message the mesh...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _send(mesh),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _send(mesh),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
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
