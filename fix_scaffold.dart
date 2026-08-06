import 'dart:io';

void main() {
  final file = File('lib/features/admin/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll(
    'ScaffoldMessenger.of(context).showSnackBar',
    'rootScaffoldMessengerKey.currentState!.showSnackBar'
  );
  
  if (!content.contains('import \'../../main.dart\';')) {
     content = content.replaceFirst('import \'package:flutter/material.dart\';', 'import \'package:flutter/material.dart\';\nimport \'../../main.dart\';');
  }
  file.writeAsStringSync(content);
  print('Replaced ScaffoldMessenger occurrences.');
}
