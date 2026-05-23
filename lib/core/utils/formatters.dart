import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class Fmt {
  static String currency(BuildContext context, double amount) {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final symbol = auth.user?.currency ?? 'USD';
      return NumberFormat.currency(symbol: '$symbol ', decimalDigits: 2).format(amount);
    } catch (e) {
      return 'USD ${amount.toStringAsFixed(2)}';
    }
  }

  static String n(double amount, {String? symbol}) {
    return NumberFormat.currency(symbol: symbol ?? '', decimalDigits: 2).format(amount);
  }
}
