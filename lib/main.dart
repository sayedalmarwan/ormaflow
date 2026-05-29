import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/task_provider.dart';
import 'screens/api_key_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_key_service.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait-only orientation for the phone UI.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge: content draws behind both the status bar and the
  // gesture/navigation bar. The system bars become fully transparent,
  // letting the app's #1B1B1B background show through everywhere.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // Status bar
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS status bar icons
      // Navigation / gesture bar
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final apiKey = await ApiKeyService.getKey();
  final hasApiKey = apiKey != null && apiKey.isNotEmpty;

  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: OrmaFlowApp(hasApiKey: hasApiKey),
    ),
  );
}

class OrmaFlowApp extends StatelessWidget {
  final bool hasApiKey;
  const OrmaFlowApp({super.key, required this.hasApiKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ormaflow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: hasApiKey ? const HomeScreen() : const ApiKeyScreen(),
    );
  }
}
