import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/constants/app_constants.dart';
import 'models/transfer_item.dart';
import 'models/device_info_model.dart';
import 'repositories/transfer_repository.dart';
import 'screens/home_screen.dart';
import 'services/nearby_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait (Mobile only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // System UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDir.path);
  }

  // Register Hive adapters
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TransferItemAdapter());
  }
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TransferStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(DeviceInfoModelAdapter());
  }

  // Open boxes
  await Hive.openBox<TransferItem>(AppConstants.transferBox);
  await Hive.openBox<String>(AppConstants.settingsBox);

  // Initialize services
  await StorageService.instance.init();
  await TransferRepository.instance.init();

  runApp(const OfflineTransferApp());
}

class OfflineTransferApp extends StatefulWidget {
  const OfflineTransferApp({super.key});

  @override
  State<OfflineTransferApp> createState() => _OfflineTransferAppState();
}

class _OfflineTransferAppState extends State<OfflineTransferApp> {
  ThemeMode _resolveThemeMode() {
    final saved = StorageService.instance.getSetting(AppConstants.keyThemeMode);
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  @override
  void dispose() {
    // Clean up NearbyService streams when the app is fully closed
    NearbyService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Transfer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _resolveThemeMode(),
      home: const HomeScreen(),
    );
  }
}
