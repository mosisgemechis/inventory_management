import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'core/services/database_service.dart';
import 'core/l10n/l10n.dart';
import 'core/providers/system_provider.dart';
import 'core/services/subscription_service.dart';
import 'core/services/push_notification_service.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runZonedGuarded(() async {
    // --- ENTERPRISE BOOT SEQUENCE ---
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env", isOptional: true);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      return false;
    };
    
    DatabaseService().ensureInitialized();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (_) {}
    }

    runApp(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: DatabaseService()),
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
    debugPrint('Zonal Error: $error');
  });
}

class InventoryManagementApp extends StatelessWidget {
  const InventoryManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, LocalizationService>(
      builder: (context, themeService, langService, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GM Inventory',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          scrollBehavior: const MaterialScrollBehavior(),
          locale: Locale(langService.currentLanguage.name),
          supportedLocales: AppLanguage.values.map((l) => Locale(l.name)).toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          builder: (context, child) {
            // Scaffold wrapping the Navigator elevates Snackbars above dialog overlays.
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: child,
            );
          },
          home: child,
        );
      },
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (!auth.initialized) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          final user = auth.user;
          if (user == null) return const LoginScreen();
          
          // Disable AXTree accessibility spam for better performance on Windows/Desktop
          return const ExcludeSemantics(child: AdminDashboardScreen());
        },
      ),
    );
  }
}
