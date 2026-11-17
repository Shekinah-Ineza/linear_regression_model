import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_loan_app/main.dart';

void main() {
  testWidgets('shows one field per input and a Predict button', (tester) async {
    await tester.pumpWidget(const KivaApp());

    expect(find.text('Predict'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(inputFields.length));
    expect(find.text('Prediction'), findsOneWidget);
  });
}
