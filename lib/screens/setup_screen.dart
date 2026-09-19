import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ble_mesh_service.dart';
import '../services/encryption_service.dart';
import '../services/permissions_service.dart';
import '../services/persistence_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _starting = false;
  String? _error;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

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
  void dispose() {
    _pulse.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              SizedBox(
                height: 180,
                width: 180,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _RadarPulsePainter(progress: _pulse.value),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'bitmesh',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A mesh chat that runs on Bluetooth alone.\n'
                'No internet, no accounts, no servers -\n'
                'every hop is encrypted device to device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.5, fontSize: 14),
              ),
              const Spacer(flex: 2),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Display name'),
                onSubmitted: (_) => _starting ? null : _startMesh(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.lost),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: AppColors.lost, fontSize: 13)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _starting ? null : _startMesh,
                  child: _starting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Text('Join mesh'),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single self-node with expanding scan rings, echoing what the app is
/// about to do (advertise + scan over BLE) rather than a generic spinner.
class _RadarPulsePainter extends CustomPainter {
  final double progress; // 0..1, looping
  _RadarPulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    for (final offset in [0.0, 0.33, 0.66]) {
      final t = (progress + offset) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppColors.signal.withValues(alpha: opacity * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawCircle(center, 8, Paint()..color = AppColors.signal);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = AppColors.signal.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}