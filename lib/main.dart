import 'package:flutter/material.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // Hive's own init happens inside PersistenceService.init() (called from
  // setup_screen once the user submits their display name), since Hive
  // needs Flutter's plugin bindings ready first - ensureInitialized covers
  // that without requiring main() itself to be async in a fragile way.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BitMeshApp());
}

class BitMeshApp extends StatelessWidget {
  const BitMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bitmesh',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SetupScreen(),
    );
  }
}
