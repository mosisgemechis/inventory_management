import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/google_setup_screen.dart';
import 'features/auth/security_setup_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'core/services/database_service.dart';
import 'core/l10n/l10n.dart';
import 'core/providers/system_provider.dart';
import 'core/services/sync/bootstrap_sync_service.dart';
import 'core/services/subscription_service.dart';
import 'core/utils/perf_logger.dart';
import 'core/config/navigation.dart';
import 'core/widgets/app_update_dialog.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runZonedGuarded(() async {
    // 1. Instant Flutter binding startup
    WidgetsFlutterBinding.ensureInitialized();
    final startupSw = Stopwatch()..start();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      return false;
    };

    // 2. Instantiate Providers with lazy background initialization
    final systemProvider = SystemProvider();
    final authService = AuthService();
    // Give AuthService a reference to SystemProvider so signOut() can pause sync.
    authService.systemProvider = systemProvider;
    final localizationService = LocalizationService();
    final themeService = ThemeService();

    runApp(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: DatabaseService()),
          ChangeNotifierProvider.value(value: systemProvider),
          ChangeNotifierProvider.value(value: authService),
          ChangeNotifierProvider(create: (_) => subscriptionService),
          ChangeNotifierProvider.value(value: localizationService),
          ChangeNotifierProvider.value(value: themeService),
        ],
        child: const InventoryManagementApp(),
      ),
    );

    // 3. Defer heavy background services initialization until AFTER initial UI paint
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final envSw = Stopwatch()..start();
      await dotenv.load(fileName: ".env", isOptional: true);
      PerfLogger.logPerformance('Startup dotenv load', envSw.elapsedMilliseconds);

      // Open the single DB connection; WAL + busy_timeout are configured there once.
      debugPrint('[DB] Creating singleton database');
      await DatabaseService().ensureInitialized();

      unawaited(() async {
        final localeSw = Stopwatch()..start();
        await localizationService.initialize();
        PerfLogger.logPerformance('Startup localizationService.initialize', localeSw.elapsedMilliseconds);
      }());

      // Enforce auth bootstrap order:
      // Database initialize -> Connection check & Cloud bootstrap sync -> Load Auth session -> SystemProvider
      unawaited(() async {
        final bootstrapSw = Stopwatch()..start();
        final bootstrap = BootstrapSyncService();
        await bootstrap.runBootstrapSync();
        PerfLogger.logPerformance('Startup bootstrapSync', bootstrapSw.elapsedMilliseconds);

        final authSw = Stopwatch()..start();
        await authService.loadSession();
        PerfLogger.logPerformance('Startup authService.loadSession', authSw.elapsedMilliseconds);

        final systemSw = Stopwatch()..start();
        await systemProvider.initialize();
        PerfLogger.logPerformance('Startup systemProvider.initialize', systemSw.elapsedMilliseconds);

        // Update check runs last so it never delays DB/identity bootstrap and
        // so the dialog appears over a mounted screen. Failures are silent.
        unawaited(checkForAppUpdateAndPrompt());
      }());
      PerfLogger.logPerformance('Startup bootstrap scheduled', startupSw.elapsedMilliseconds);
    });

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
          title: 'GM Inventory Everywhere',
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
          navigatorKey: rootNavigatorKey,
          builder: (context, child) {
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
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Initializing GM Inventory Everywhere Engine...',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = auth.user;
          if (user == null) return const LoginScreen(key: ValueKey('login_screen'));

          if (auth.needsGoogleSetup) {
            return const GoogleSetupScreen(key: ValueKey('google_setup_screen'));
          }

          if (auth.needsSecuritySetup) {
            return const SecuritySetupScreen(
                key: ValueKey('security_setup_screen'));
          }

          return ExcludeSemantics(
            key: ValueKey('admin_dashboard_${user.id}_${user.shopId}'),
            child: const AdminDashboardScreen(),
          );
        },
      ),
    );
  }
}
