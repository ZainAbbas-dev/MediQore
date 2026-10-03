import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/theme/app_colors.dart';
import 'package:mediqore/widgets/risk_chip.dart';

import '../helpers.dart';

void main() {
  const expected = {
    RiskLevel.green: ('کم خطرہ', AppColors.riskGreen),
    RiskLevel.yellow: ('درمیانہ خطرہ', AppColors.riskYellow),
    RiskLevel.red: ('زیادہ خطرہ', AppColors.riskRed),
  };

  for (final MapEntry(key: level, value: (label, colour)) in expected.entries) {
    testWidgets('$level shows its Urdu label, colour and an icon', (tester) async {
      await tester.pumpWidget(wrapInApp(RiskChip(level: level)));
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(RiskChip), matching: find.byType(DecoratedBox)),
      );
      expect((box.decoration as BoxDecoration).color, colour);
    });
  }
}
