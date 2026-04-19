import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/services/auth_service.dart';
import 'core/models/models.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/staff/staff_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/firestore_service.dart';
import 'core/l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  String? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 🔥 CRITICAL FIX FOR WEB & DESKTOP ASSERTION ERRORS 
    if (kIsWeb) {
      try {
        await FirebaseFirestore.instance.clearPersistence();
      } catch (e) {
        debugPrint("Persistence clear skipped: $e");
      }
    } else {
      // Native Platform logic
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      } else {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      }
    }
    NotificationService.initialize().catchError((e) => debugPrint("Notification error: $e"));

    // Sync starts centrally via AuthService mapping
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'app_title'.tr(context),
      theme: AppTheme.lightTheme,
      locale: Locale(Provider.of<LocalizationService>(context).currentLanguage.name),
      supportedLocales: const [Locale('en'), Locale('am')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: initError != null 
        ? Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 10),
                    const Text('Critical System Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(initError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: () => main(), child: const Text("Retry Connection"))
                  ]
                )
              )
            )
          )
        : Consumer<AuthService>(
            builder: (context, auth, _) {
              if (!auth.initialized) {
                 return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (auth.user == null) {
                return LoginScreen();
              }
              final role = auth.user?.role;
              if (role == UserRole.admin) {
                return AdminDashboardScreen();
              } else if (role == UserRole.staff || role == UserRole.cashier) {
                return StaffDashboardScreen();
              } else {
                return const Scaffold(body: Center(child: Text("Access Denied: Unrecognized Role")));
              }
            },
          ),
    );
  }
}
