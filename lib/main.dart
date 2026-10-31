import 'package:flutter/material.dart';

import 'backend/backend.dart';
import 'backend/select_backend.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await selectBackend();
  runApp(MyWeekApp(backend: backend));
}

class MyWeekApp extends StatelessWidget {
  const MyWeekApp({super.key, required this.backend});

  final Backend backend;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Week',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: AuthGate(backend: backend),
    );
  }
}
