import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/models/models.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/colors.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'core/services/notification_service.dart';
import 'core/services/database_service.dart';
import 'core/l10n/l10n.dart';
import 'core/providers/system_provider.dart';
import 'core/services/subscription_service.dart';

void main() async {
  // --- ENTERPRISE BOOT SEQUENCE ---
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // TODO: persist to local diagnostics table and/or upload via sync when online.
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // TODO: persist to local diagnostics table and/or upload via sync when online.
    return false;
  };
  
  // Drift is the single source of truth - initialized lazily on first access.
  // We trigger a light query in background to ensure readiness without blocking.
  DatabaseService().ensureInitialized();

  runZonedGuarded(() {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SystemProvider()..initialize()),
          ChangeNotifierProvider(create: (_) => AuthService()..loadSession()),
          ChangeNotifierProvider(create: (_) => subscriptionService),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
        ],
        child: const InventoryManagementApp(),
      ),
    );
  }, (error, stack) {
    // TODO: persist to local diagnostics table and/or upload via sync when online.
  });
}

class InventoryManagementApp extends StatelessWidget {
  const InventoryManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GM Inventory',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      scrollBehavior: const MaterialScrollBehavior(),
      locale: Locale(Provider.of<LocalizationService>(context).currentLanguage.name),
      supportedLocales: AppLanguage.values.map((l) => Locale(l.name)).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          // LIFT-OFF: Check if Auth is ready with Local Cache
          if (!auth.initialized) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          final user = auth.user;
          if (user == null) return const LoginScreen();
          
          // INDUSTRIAL DASHBOARD SELECTOR - Unified to AdminDashboard with role-gating
          return const AdminDashboardScreen();
        },
      ),
    );
  }
}
