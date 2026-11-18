import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/features/subscription/checkout_flow.dart';

Widget _host({required Brightness brightness}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ),
    home: Scaffold(
      body: CheckoutFlow(
        plan: SubscriptionPlan.starter,
        addOns: const [SubscriptionAddOn.extraUser],
        total: 18,
        initialCardMethod: true,
        onPay: () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('review step continues to the payment step (light)',
      (tester) async {
    await tester.pumpWidget(_host(brightness: Brightness.light));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Continue to payment'), findsOneWidget);

    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();

    expect(find.text('Card number'), findsOneWidget);
    expect(find.text('Telebirr number'), findsNothing);
    expect(find.text('Pay USD 18.00'), findsOneWidget);
  });

  testWidgets('renders in dark mode without errors', (tester) async {
    await tester.pumpWidget(_host(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(find.text('Secure checkout'), findsOneWidget);
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
