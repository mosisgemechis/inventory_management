import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

enum AppLanguage { en, am }

class LocalizationService with ChangeNotifier {
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'SmartInventory ERP',
      'login': 'Login',
      'username': 'Username',
      'password': 'Password',
      'role': 'Role',
      'admin': 'Admin',
      'staff': 'Staff',
      'cashier': 'Cashier',
      'sell': 'Sell',
      'inventory': 'Inventory',
      'reports': 'Reports',
      'suppliers': 'Suppliers',
      'purchases': 'Purchases',
      'analytics': 'Analytics',
      'audit_logs': 'Audit Logs',
      'settings': 'Settings',
      'logout': 'Logout',
      'low_stock': 'Low Stock Alerts',
      'total_sales': 'Total Sales',
      'profit': 'Profit',
      'add_item': 'Add Item',
      'search': 'Search...',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'language': 'Language',
      'amharic': 'Amharic (አማርኛ)',
      'english': 'English',
      'kibid': 'Customer Debt (Kibid)',
      'batch_no': 'Batch Number',
      'expiry': 'Expiry Date',
      'daily_sales': 'Daily Sales',
      'daily_profit': 'Daily Profit',
      'monthly_profit': 'Monthly Profit',
      'target_branch': 'Target Branch',
      'initial_stock': 'Initial Stock',
      'add_branch': 'Add Branch',
      'add_user': 'Add User',
      'set_price': 'Set Price',
      'branch': 'Branch',
    },
    'am': {
      'app_title': 'ስማርት ኢንቬንተሪ ERP',
      'login': 'ይግቡ',
      'username': 'የተጠቃሚ ስም',
      'password': 'የይለፍ ቃል',
      'role': 'ተግባር',
      'admin': 'አስተዳዳሪ',
      'staff': 'ሰራተኛ',
      'cashier': 'ሂሳብ ተቀባይ',
      'sell': 'መሸጥ',
      'inventory': 'ክምችት',
      'reports': 'ሪፖርቶች',
      'suppliers': 'አቅራቢዎች',
      'purchases': 'ግዢዎች',
      'analytics': 'ትንታኔዎች',
      'audit_logs': 'ኦዲት',
      'settings': 'ቅንብሮች',
      'logout': 'ይውጡ',
      'low_stock': 'ዝቅተኛ ክምችት ማስጠንቀቂያ',
      'total_sales': 'ጠቅላላ ሽያጭ',
      'profit': 'ትርፍ',
      'add_item': 'እቃ ጨምር',
      'search': 'ፈልግ...',
      'save': 'አስቀምጥ',
      'cancel': 'ሰርዝ',
      'confirm': 'አረጋግጥ',
      'language': 'ቋንቋ',
      'amharic': 'አማርኛ',
      'english': 'እንግሊዝኛ',
      'kibid': 'የደንበኛ ዕዳ (ኪቢድ)',
      'batch_no': 'ባች ቁጥር',
      'expiry': 'የአገልግሎት ማብቂያ ቀን',
      'daily_sales': 'የቀን ሽያጭ',
      'daily_profit': 'የቀን ትርፍ',
      'monthly_profit': 'የወር ትርፍ',
      'target_branch': 'ኢላማ ቅርንጫፍ',
      'initial_stock': 'መጀመሪያ ክምችት',
      'add_branch': 'ቅርንጫፍ ጨምር',
      'add_user': 'ተጠቃሚ ጨምር',
      'set_price': 'ዋጋ ወስን',
      'branch': 'ቅርንጫፍ',
    }
  };

  AppLanguage _currentLanguage = AppLanguage.en;
  AppLanguage get currentLanguage => _currentLanguage;

  LocalizationService() {
    _loadLanguage();
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';
    _currentLanguage = langCode == 'am' ? AppLanguage.am : AppLanguage.en;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', language == AppLanguage.am ? 'am' : 'en');
    notifyListeners();
  }

  String translate(String key) {
    return _translations[_currentLanguage.name]?[key] ?? key;
  }
}

extension TranslateExtension on String {
  String tr(BuildContext context) {
    return Provider.of<LocalizationService>(context).translate(this);
  }
}
