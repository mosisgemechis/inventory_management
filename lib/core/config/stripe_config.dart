import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeConfig {
  static String get publishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  static String get secretKey => dotenv.env['STRIPE_SECRET_KEY'] ?? '';

  static bool get isConfigured =>
      publishableKey.isNotEmpty && secretKey.isNotEmpty;
}
