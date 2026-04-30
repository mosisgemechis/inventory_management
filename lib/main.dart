import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/models/models.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/colors.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/staff/staff_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'core/services/notification_service.dart';
import 'core/l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(AppUserAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(SaleAdapter());
  Hive.registerAdapter(PurchaseRecordAdapter());
  Hive.registerAdapter(CartItemAdapter());
  Hive.registerAdapter(TimestampAdapter());

  String? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    }
    
    NotificationService.initialize().catchError((e) => debugPrint("Notification error: $e"));

  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      initError = e.toString();
    } else {
      NotificationService.initialize().catchError((e) => debugPrint("Notification error: $e"));
    }
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: InventoryManagementApp(initError: initError),
    ),
  );
}

class InventoryManagementApp extends StatelessWidget {
  final String? initError;
  const InventoryManagementApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartInventory ERP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      locale: Locale(Provider.of<LocalizationService>(context).currentLanguage.name),

      supportedLocales: const [Locale('en'), Locale('am')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: initError != null 
        ? _buildErrorScreen()
        : Consumer<AuthService>(
            builder: (context, auth, _) {
              if (!auth.initialized) {
                 return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final user = auth.user;
              if (user == null) return const LoginScreen();
              
              if (user.roles.contains(UserRole.admin) || user.roles.contains(UserRole.manager) || user.roles.contains(UserRole.staff)) {
                return const AdminDashboardScreen();
              } else {
                return const Scaffold(body: Center(child: Text("Access Denied: Unrecognized Role")));
              }
            },
          ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 64),
              const SizedBox(height: 24),
              const Text('System Initialization Failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 12),
              Text(initError ?? 'Unknown error occurred', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: () => main(), child: const Text("Retry System Boot"))
            ]
          )
        )
      )
    );
  }
}
