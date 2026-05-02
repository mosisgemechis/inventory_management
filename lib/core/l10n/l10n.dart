import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

enum AppLanguage { en, am, ar, fr, es, hi, zh, sw, pt }

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
      'debt': 'Customer Debt',
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
      'dashboard': 'Dashboard',
      'sales_pos': 'Sales (POS)',
      'inventory_control': 'Inventory Control',
      'audit_history': 'Audit History',
      'request_deletion': 'Request Deletion',
      'low_stock_limit': 'Low Stock Alert',
    },
    'am': {
      'app_title': 'SmartInventory ERP',
      'login': 'ይግቡ',
      'username': 'የተጠቃሚ ስም',
      'password': 'የይለፍ ቃል',
      'role': 'ተግባር',
      'admin': 'አስተዳዳሪ',
      'staff': 'ሰራተኛ',
      'cashier': 'ሂሳብ ተቀባይ',
      'sell': 'ሽያጭ',
      'inventory': 'ክምችት / ኢንቬንተሪ',
      'reports': 'ሪፖርቶች',
      'suppliers': 'አቅራቢዎች',
      'purchases': 'ግዢዎች',
      'analytics': 'ተንታኝ',
      'audit_logs': 'የእንቅስቃሴ መዝገብ',
      'settings': 'ቅንብሮች',
      'logout': 'ይውጡ',
      'low_stock': 'ዝቅተኛ ክምችት ማስጠንቀቂያ',
      'total_sales': 'ጠቅላላ ሽያጭ',
      'profit': 'ትርፍ',
      'add_item': 'አዲስ ዕቃ ጨምር',
      'search': 'ፈልግ...',
      'save': 'አስቀምጥ',
      'cancel': 'ሰርዝ',
      'confirm': 'አረጋግጥ',
      'language': 'ቋንቋ',
      'amharic': 'አማርኛ',
      'english': 'እንግሊዝኛ',
      'debt': 'የደንበኛ ዕዳ',
      'batch_no': 'ባች ቁጥር',
      'expiry': 'የአገልግሎት ማብቂያ ቀን',
      'daily_sales': 'የቀን ሽያጭ',
      'daily_profit': 'የቀን ትርፍ',
      'monthly_profit': 'የወር ትርፍ',
      'target_branch': 'ቅርንጫፍ',
      'initial_stock': 'የመጀመሪያ ክምችት',
      'add_branch': 'ቅርንጫፍ ጨምር',
      'add_user': 'ተጠቃሚ ጨምር',
      'set_price': 'ዋጋ ወስን',
      'branch': 'ቅርንጫፍ',
      'dashboard': 'ዳሽቦርድ',
      'sales_pos': 'POS ሽያጭ',
      'inventory_control': 'ክምችት ተቆጣጣሪ',
      'audit_history': 'የእንቅስቃሴ ታሪክ',
      'request_deletion': 'የስረዛ ጥያቄ',
      'low_stock_limit': 'ዝቅተኛ ክምችት',
    },
    'ar': { 
      'app_title': 'سارت إنفنتوري ERP', 'login': 'تسجيل الدخول', 
      'inventory': 'المخزون', 'reports': 'التقارير', 'settings': 'الإعدادات',
      'dashboard': 'لوحة القيادة', 'sales_pos': 'نقطة البيع (POS)',
      'purchases': 'المشتريات', 'debt': 'ديون العملاء',
      'add_user': 'إضافة مستخدم', 'audit_history': 'سجل التدقيق',
      'inventory_control': 'مراقبة المخزون'
    },
    'fr': { 
      'app_title': 'SmartInventory ERP', 'login': 'Connexion', 
      'inventory': 'Inventaire', 'reports': 'Rapports', 'settings': 'Paramètres',
      'dashboard': 'Tableau de Bord', 'sales_pos': 'Point de Vente (POS)',
      'purchases': 'Achats', 'debt': 'Dettes Clients',
      'add_user': 'Ajouter Utilisateur', 'audit_history': 'Historique Audit',
      'inventory_control': 'Contrôle d\'Inventaire'
    },
    'es': { 
      'app_title': 'SmartInventory ERP', 'login': 'Acceso', 
      'inventory': 'Inventario', 'reports': 'Informes', 'settings': 'Ajustes',
      'dashboard': 'Panel de Control', 'sales_pos': 'Punto de Venta (POS)',
      'purchases': 'Compras', 'debt': 'Deuda del Cliente',
      'add_user': 'Agregar Usuario', 'audit_history': 'Historial de Auditoría',
      'inventory_control': 'Control de Inventario'
    },
    'hi': { 
      'app_title': 'स्मार्टइन्वेंटरी ERP', 'login': 'लॉगिन', 
      'inventory': 'इन्वेंटरी', 'reports': 'रिपोर्ट', 'settings': 'सेटिंग्स',
      'dashboard': 'डैशबोर्ड', 'sales_pos': 'बिक्री (POS)',
      'purchases': 'खरीद', 'debt': 'ग्राहक ऋण',
      'add_user': 'उपयोगकर्ता जोड़ें', 'audit_history': 'ऑडिट इतिहास',
      'inventory_control': 'इन्वेंट्री नियंत्रण'
    },
    'zh': { 
      'app_title': '智慧库存 ERP', 'login': '登录', 
      'inventory': '库存', 'reports': '报告', 'settings': '设置',
      'dashboard': '仪表板', 'sales_pos': '销售终端 (POS)',
      'purchases': '采购', 'debt': '客户债务',
      'add_user': '添加用户', 'audit_history': '审计历史',
      'inventory_control': '库存控制'
    },
    'sw': { 
      'app_title': 'SmartInventory ERP', 'login': 'Ingia', 
      'inventory': 'Hesabu', 'reports': 'Ripoti', 'settings': 'Mipangilio',
      'dashboard': 'Dashibodi', 'sales_pos': 'Mauzo (POS)',
      'purchases': 'Ununuzi', 'debt': 'Deni la Mteja',
      'add_user': 'Ongeza Mtumiaji', 'audit_history': 'Historia ya Ukaguzi',
      'inventory_control': 'Udhibiti wa Hesabu'
    },
    'pt': { 
      'app_title': 'SmartInventory ERP', 'login': 'Entrar', 
      'inventory': 'Inventário', 'reports': 'Relatórios', 'settings': 'Configurações',
      'dashboard': 'Painel de Controlo', 'sales_pos': 'Ponto de Venda (POS)',
      'purchases': 'Compras', 'debt': 'Dívida do Cliente',
      'add_user': 'Adicionar Utilizador', 'audit_history': 'Histórico de Auditoria',
      'inventory_control': 'Controlo de Inventário'
    },
  };

  AppLanguage _currentLanguage = AppLanguage.en;
  AppLanguage get currentLanguage => _currentLanguage;

  LocalizationService() {
    _loadLanguage();
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';
    _currentLanguage = AppLanguage.values.firstWhere(
      (l) => l.name == langCode,
      orElse: () => AppLanguage.en
    );
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', language.name);
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
