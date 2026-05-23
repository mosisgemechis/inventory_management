import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class CurrencyFormatter {
  static String format(BuildContext context, double amount) {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final currency = auth.user?.currency ?? 'USD';
      
      // Special handling for Ethiopian Birr as requested
      if (currency.toUpperCase() == 'ETB' || currency.toUpperCase() == 'BIRR') {
        return '${NumberFormat("#,##0.00").format(amount)} Birr';
      }
      
      // Global standard formatting for others
      return '${currency.toUpperCase()} ${NumberFormat("#,##0.00").format(amount)}';
    } catch (e) {
      return '$amount';
    }
  }

  static String simple(double amount, String currency) {
    if (currency.toUpperCase() == 'ETB' || currency.toUpperCase() == 'BIRR') {
      return '${NumberFormat("#,##0.00").format(amount)} Birr';
    }
    return '${currency.toUpperCase()} ${NumberFormat("#,##0.00").format(amount)}';
  }
}
