import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'models/task.dart';
import 'providers/task_provider.dart';
import 'screens/api_key_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_key_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
  // letting the app's background show through everywhere.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // Status bar
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      // Navigation / gesture bar
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── Hive initialisation ───────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(TaskTypeAdapter());
  Hive.registerAdapter(TaskAdapter());

  final tasksBox = await Hive.openBox<Task>(TaskProvider.tasksBoxName);
  final trashBox = await Hive.openBox<Task>(TaskProvider.trashBoxName);

  // ── API key check (for routing) ───────────────
  final apiKey = await ApiKeyService.getKey();
  final hasApiKey = apiKey != null && apiKey.isNotEmpty;

  // ── Build provider with Hive boxes ───────────
  final taskProvider = TaskProvider()..init(tasksBox, trashBox);

  runApp(
    ChangeNotifierProvider.value(
      value: taskProvider,
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      home: hasApiKey ? const HomeScreen() : const ApiKeyScreen(),
    );
  }
}
