import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restoreai/main.dart';

void main() {
  testWidgets('Colab server dialog opens and closes safely', (tester) async {
    await tester.pumpWidget(const RestoreAIApp());
    await tester.ensureVisible(find.text('ربط خادم Colab المؤقت'));
    await tester.tap(find.text('ربط خادم Colab المؤقت'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Colab server dialog can submit a valid HTTPS URL', (tester) async {
    await tester.pumpWidget(const RestoreAIApp());
    await tester.ensureVisible(find.text('ربط خادم Colab المؤقت'));
    await tester.tap(find.text('ربط خادم Colab المؤقت'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first,
        'https://restoreai-test.trycloudflare.com');
    await tester.enterText(find.byType(TextField).last, 'test-token');
    await tester.tap(find.text('اتصال'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('الخادم مضبوط'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
