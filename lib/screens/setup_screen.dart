import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_mesh_service.dart';
import '../services/encryption_service.dart';
import '../services/permissions_service.dart';
import '../services/persistence_service.dart';
import 'chat_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  bool _starting = false;
  String? _error;

  Future<void> _startMesh() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a display name');
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });

    final granted = await PermissionsService.requestAll();
    if (!granted) {
      setState(() {
        _starting = false;
        _error = 'Bluetooth/location permissions are required for mesh chat';
      });
      return;
    }

    // No passphrase to enter anymore - each device generates its own X25519
    // identity keypair and negotiates a fresh encrypted session with every
    // peer it connects to directly (see encryption_service.dart).
    final encryption = EncryptionService();
    await encryption.init();

    final persistence = PersistenceService();
    await persistence.init();

    final meshService = BleMeshService(
      encryption: encryption,
      persistence: persistence,
      selfDisplayName: _nameController.text.trim(),
    );
    await meshService.start();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: meshService,
          child: const ChatScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('bitmesh')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Decentralized mesh chat over Bluetooth.\nNo internet, no accounts, no servers.\nEach connection is individually encrypted.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _starting ? null : _startMesh,
              child: _starting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join mesh'),
            ),
          ],
        ),
      ),
    );
  }
}
