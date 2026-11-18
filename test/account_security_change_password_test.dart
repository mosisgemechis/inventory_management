import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/widgets/account_security_dialog.dart';

void main() {
  testWidgets('Account Security: Change password opens the password dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AccountSecurityDialog(
                    methodsLoader: () async => {
                      'password_configured': true,
                      'username': 'testuser',
                      'google_connected': true,
                      'google_email': 'test@example.com',
                      'recovery_email': '',
                      'recovery_email_verified': false,
                    },
                  ),
                ),
                child: const Text('Open security'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open security'));
    await tester.pumpAndSettle();

    // The security overview is loaded and offers the password action.
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Update Password'), findsNothing);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    // The change-password form is actually on screen.
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
    expect(find.text('Current Password'), findsOneWidget);
  });
}
